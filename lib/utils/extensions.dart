import 'package:flutter/material.dart';

import '../models/report_model.dart';

extension ReportCategoryX on ReportCategory {
  String get displayName => switch (this) {
    ReportCategory.infrastructure => 'Infrastructure',
    ReportCategory.environment => 'Environment',
    ReportCategory.safety => 'Safety',
    ReportCategory.public_service => 'Public Service',
    ReportCategory.appreciation => 'Appreciation',
    ReportCategory.other => 'Other',
  };

  IconData get icon => switch (this) {
    ReportCategory.infrastructure => Icons.construction,
    ReportCategory.environment => Icons.eco,
    ReportCategory.safety => Icons.shield_outlined,
    ReportCategory.public_service => Icons.account_balance,
    ReportCategory.appreciation => Icons.star,
    ReportCategory.other => Icons.report_problem,
  };
}

extension ReportSeverityX on ReportSeverity {
  Color color(ColorScheme cs) => switch (this) {
    ReportSeverity.low => Colors.green,
    ReportSeverity.medium => Colors.orange,
    ReportSeverity.high => cs.error,
    ReportSeverity.critical => Colors.purple,
  };

  String get displayName => name[0].toUpperCase() + name.substring(1);
}

extension ReportStatusX on ReportStatus {
  String get displayName => name.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');

  Color color(ColorScheme cs) => switch (this) {
    ReportStatus.pending => Colors.grey,
    ReportStatus.under_review => Colors.blue,
    ReportStatus.in_progress => Colors.orange,
    ReportStatus.resolved => Colors.green,
    ReportStatus.closed => cs.error,
  };
}

extension StringX on String {
  String get capitalised => isEmpty ? this : this[0].toUpperCase() + substring(1);
}

extension BuildContextX on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
}
