import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/constituency_model.dart';
import '../services/constituency_service.dart';

// Args record used as family key (Dart records are equality-comparable)
typedef ConstArgs = ({
  String city,
  String? district,
  String? ward,
  String? pincode,
  String? category,
});

final constituencyLookupProvider =
    FutureProvider.autoDispose.family<ConstituencyInfo, ConstArgs>((ref, args) {
  return ref.read(constituencyServiceProvider).lookup(
        pincode: args.pincode,
        city: args.city,
        district: args.district,
        ward: args.ward,
        issueCategory: args.category,
      );
});
