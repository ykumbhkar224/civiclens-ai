import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/constituency_model.dart';
import '../models/issue_model.dart';
import '../config/supabase_config.dart';

part 'constituency_service.g.dart';

@Riverpod(keepAlive: true)
ConstituencyService constituencyService(Ref ref) => ConstituencyService();

class ConstituencyService {
  final _client = SupabaseConfig.client;

  Future<ConstituencyInfo> lookup({
    String? pincode,
    required String city,
    String? district,
    String? ward,
    String? issueCategory,
  }) async {
    try {
      String? assemblyConst;
      String? parliamentConst;
      String? resolvedPincode = pincode;

      // Step 1a: resolve constituency names from exact pincode
      if (pincode != null && pincode.length >= 5) {
        final rows1a = await _client
            .from('pincode_constituencies')
            .select()
            .eq('pincode', pincode)
            .limit(1) as List;
        final row = rows1a.isNotEmpty ? rows1a.first as Map<String, dynamic> : null;

        if (row == null && pincode.length >= 4) {
          final rows = await _client
              .from('pincode_constituencies')
              .select()
              .ilike('pincode', '${pincode.substring(0, 4)}%')
              .eq('city', city)
              .limit(1) as List;
          if (rows.isNotEmpty) {
            assemblyConst = rows.first['assembly_constituency'] as String?;
            parliamentConst = rows.first['parliament_constituency'] as String?;
            resolvedPincode = rows.first['pincode'] as String?;
          }
        } else if (row != null) {
          assemblyConst = row['assembly_constituency'] as String?;
          parliamentConst = row['parliament_constituency'] as String?;
        }
      }

      // Step 1b: if no pincode match, resolve constituencies by city name.
      // Normalise suffixes and split compound names ("Pimpri-Chinchwad" → ["Pimpri","Chinchwad"]).
      if (assemblyConst == null) {
        String _normalize(String c) => c
            .replaceAll(RegExp(r'\s+Subdistrict$', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s+District$', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s+Taluka$', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s+Block$', caseSensitive: false), '')
            .replaceAll(RegExp(r'\s+Municipal\s+Corp.*$', caseSensitive: false), '')
            .trim();

        List<String> _variants(String c) {
          final norm = _normalize(c);
          return <String>{
            c,
            norm,
            // split hyphenated compound names: "Pimpri-Chinchwad" → "Pimpri", "Chinchwad"
            ...norm.split(RegExp(r'[-–—]')).map((p) => p.trim()),
          }.where((s) => s.isNotEmpty).toList();
        }

        final cityAlts = <String>{
          ..._variants(city),
          if (district != null && district.isNotEmpty) ..._variants(district),
        }.where((c) => c.isNotEmpty).toList();

        for (final c in cityAlts) {
          final rows = await _client
              .from('pincode_constituencies')
              .select()
              .ilike('city', c)
              .limit(1) as List;
          if (rows.isNotEmpty) {
            assemblyConst = rows.first['assembly_constituency'] as String?;
            parliamentConst = rows.first['parliament_constituency'] as String?;
            resolvedPincode ??= rows.first['pincode'] as String?;
            break;
          }
        }
      }

      final cityAlternates = <String>[
        city,
        if (district != null && district.isNotEmpty && district != city) district,
      ];

      // Step 2: MLA lookup — by assembly constituency name, then constituency ILIKE city fallback
      RepresentativeModel? mla;
      if (assemblyConst != null) {
        final mlaRows = await _client
            .from('representatives')
            .select()
            .eq('constituency', assemblyConst)
            .eq('type', 'mla')
            .limit(1) as List;
        if (mlaRows.isNotEmpty) mla = RepresentativeModel.fromJson(mlaRows.first as Map<String, dynamic>);
      }
      if (mla == null) {
        // Fallback: constituency name contains city (e.g., "Pune City", "Nashik Central")
        for (final c in cityAlternates) {
          final rows = await _client
              .from('representatives')
              .select()
              .ilike('constituency', '%$c%')
              .eq('type', 'mla')
              .limit(1) as List;
          if (rows.isNotEmpty) {
            mla = RepresentativeModel.fromJson(rows.first as Map<String, dynamic>);
            break;
          }
        }
      }

      // Step 3: MP lookup — by parliament constituency name, then city match
      // Note: pincode_constituencies may use "Bengaluru" while representatives uses
      // the older "Bangalore" spelling — normalise before querying.
      String normaliseConst(String s) => s
          .replaceAll('Bengaluru', 'Bangalore')
          .replaceAll('bengaluru', 'bangalore');

      RepresentativeModel? mp;
      if (parliamentConst != null) {
        // Try exact ILIKE (case-insensitive) with original name
        final mpRows = await _client
            .from('representatives')
            .select()
            .ilike('constituency', parliamentConst)
            .eq('type', 'mp')
            .limit(1) as List;
        if (mpRows.isNotEmpty) {
          mp = RepresentativeModel.fromJson(mpRows.first as Map<String, dynamic>);
        }
        // Try with normalised name (Bengaluru→Bangalore) if still null
        if (mp == null) {
          final normConst = normaliseConst(parliamentConst);
          if (normConst != parliamentConst) {
            final normRows = await _client
                .from('representatives')
                .select()
                .ilike('constituency', normConst)
                .eq('type', 'mp')
                .limit(1) as List;
            if (normRows.isNotEmpty) {
              mp = RepresentativeModel.fromJson(normRows.first as Map<String, dynamic>);
            }
          }
        }
      }
      if (mp == null) {
        // Fallback: MPs stored with constituency city — direct city match
        for (final c in cityAlternates) {
          for (final name in [c, normaliseConst(c)]) {
            final rows = await _client
                .from('representatives')
                .select()
                .ilike('city', name)
                .eq('type', 'mp')
                .limit(1) as List;
            if (rows.isNotEmpty) {
              mp = RepresentativeModel.fromJson(rows.first as Map<String, dynamic>);
              break;
            }
          }
          if (mp != null) break;
        }
      }
      if (mp == null) {
        // Constituency ILIKE city fallback for MPs
        for (final c in cityAlternates) {
          for (final name in [c, normaliseConst(c)]) {
            final rows = await _client
                .from('representatives')
                .select()
                .ilike('constituency', '%$name%')
                .eq('type', 'mp')
                .limit(1) as List;
            if (rows.isNotEmpty) {
              mp = RepresentativeModel.fromJson(rows.first as Map<String, dynamic>);
              break;
            }
          }
          if (mp != null) break;
        }
      }

      // Step 4: Councillor lookup — ward match within city, then city fallback
      RepresentativeModel? councillor;
      if (ward != null && ward.trim().isNotEmpty) {
        for (final c in cityAlternates) {
          final rows = await _client
              .from('representatives')
              .select()
              .eq('city', c)
              .eq('type', 'councillor')
              .ilike('ward', '%${ward.trim()}%')
              .limit(1) as List;
          if (rows.isNotEmpty) {
            councillor = RepresentativeModel.fromJson(rows.first as Map<String, dynamic>);
            break;
          }
        }
      }
      if (councillor == null) {
        for (final c in cityAlternates) {
          final rows = await _client
              .from('representatives')
              .select()
              .eq('city', c)
              .eq('type', 'councillor')
              .limit(1) as List;
          if (rows.isNotEmpty) {
            councillor = RepresentativeModel.fromJson(rows.first as Map<String, dynamic>);
            break;
          }
        }
      }

      // Step 5: Department / authority lookup
      String? deptCity;
      for (final c in cityAlternates) {
        final test = await _client
            .from('authorities')
            .select('id')
            .eq('city', c)
            .limit(1) as List;
        if (test.isNotEmpty) {
          deptCity = c;
          break;
        }
      }
      var deptQuery =
          _client.from('authorities').select().eq('city', deptCity ?? city);
      if (issueCategory != null) {
        deptQuery = deptQuery.contains('categories', [issueCategory]);
      }
      final deptRows = await deptQuery.limit(4) as List;
      final departments =
          deptRows.map((d) => AuthorityModel.fromJson(d)).toList();

      return ConstituencyInfo(
        pincode: resolvedPincode ?? pincode,
        city: city,
        ward: ward,
        assemblyConstituency: assemblyConst,
        parliamentConstituency: parliamentConst,
        mla: mla,
        mp: mp,
        councillor: councillor,
        departments: departments,
      );
    } catch (e) {
      debugPrint('ConstituencyService.lookup: $e');
      return ConstituencyInfo.empty(city);
    }
  }
}
