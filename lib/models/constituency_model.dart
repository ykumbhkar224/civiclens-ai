import 'issue_model.dart';

class ConstituencyInfo {
  final String? pincode;
  final String city;
  final String? ward;
  final String? assemblyConstituency;
  final String? parliamentConstituency;
  final RepresentativeModel? mla;
  final RepresentativeModel? mp;
  final RepresentativeModel? councillor;
  final List<AuthorityModel> departments;

  const ConstituencyInfo({
    this.pincode,
    required this.city,
    this.ward,
    this.assemblyConstituency,
    this.parliamentConstituency,
    this.mla,
    this.mp,
    this.councillor,
    this.departments = const [],
  });

  bool get hasPoliticalData =>
      mla != null || mp != null || councillor != null;

  bool get hasData =>
      hasPoliticalData || departments.isNotEmpty;

  static ConstituencyInfo empty(String city) =>
      ConstituencyInfo(city: city, departments: const []);
}
