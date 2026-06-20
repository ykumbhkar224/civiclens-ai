import 'package:flutter/material.dart';

import '../models/issue_model.dart';

/// Per-category gradient and accent colour, used across cards and banners.
class CategoryTheme {
  static LinearGradient gradient(String category) => switch (category) {
        IssueCat.infrastructure => const LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        IssueCat.safety => const LinearGradient(
            colors: [Color(0xFF7F1D1D), Color(0xFFDC2626)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        IssueCat.environment => const LinearGradient(
            colors: [Color(0xFF14532D), Color(0xFF16A34A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        IssueCat.water => const LinearGradient(
            colors: [Color(0xFF0C4A6E), Color(0xFF0891B2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        IssueCat.electricity => const LinearGradient(
            colors: [Color(0xFF78350F), Color(0xFFD97706)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        IssueCat.roads => const LinearGradient(
            colors: [Color(0xFF1C1917), Color(0xFF57534E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        IssueCat.transport => const LinearGradient(
            colors: [Color(0xFF312E81), Color(0xFF6D28D9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        IssueCat.healthcare => const LinearGradient(
            colors: [Color(0xFF831843), Color(0xFFDB2777)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        IssueCat.publicService => const LinearGradient(
            colors: [Color(0xFF134E4A), Color(0xFF0D9488)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        _ => const LinearGradient(
            colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
      };

  static Color accent(String category) => switch (category) {
        IssueCat.infrastructure => const Color(0xFF2563EB),
        IssueCat.safety => const Color(0xFFDC2626),
        IssueCat.environment => const Color(0xFF16A34A),
        IssueCat.water => const Color(0xFF0891B2),
        IssueCat.electricity => const Color(0xFFD97706),
        IssueCat.roads => const Color(0xFF78716C),
        IssueCat.transport => const Color(0xFF6D28D9),
        IssueCat.healthcare => const Color(0xFFDB2777),
        IssueCat.publicService => const Color(0xFF0D9488),
        _ => const Color(0xFF2563EB),
      };
}
