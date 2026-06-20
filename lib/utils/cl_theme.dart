import 'package:flutter/material.dart';

/// CivicLens design tokens — single source of truth for colours, radii, etc.
class CL {
  // ── Primary palette ───────────────────────────────────────────────────────
  static const green       = Color(0xFF16A34A);
  static const greenLight  = Color(0xFF22C55E);
  static const greenDark   = Color(0xFF15803D);
  static const greenBg     = Color(0xFFDCFCE7);

  static const purple      = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFF8B5CF6);
  static const purpleBg    = Color(0xFFEDE9FE);

  // ── Tag colours ───────────────────────────────────────────────────────────
  static const issueRed    = Color(0xFFEF4444);
  static const issueRedBg  = Color(0xFFFEE2E2);

  static const appPurple   = Color(0xFF7C3AED);
  static const appPurpleBg = Color(0xFFEDE9FE);

  static const updateBlue  = Color(0xFF2563EB);
  static const updateBlueBg = Color(0xFFDBEAFE);

  // ── Neutrals ──────────────────────────────────────────────────────────────
  static const bg          = Color(0xFFF4F4F5);
  static const card        = Colors.white;
  static const divider     = Color(0xFFE5E7EB);
  static const text1       = Color(0xFF111827);
  static const text2       = Color(0xFF6B7280);
  static const text3       = Color(0xFF9CA3AF);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const headerGradient = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const greenGradient = LinearGradient(
    colors: [Color(0xFF16A34A), Color(0xFF22C55E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Helpers ───────────────────────────────────────────────────────────────
  static Color tagColor(String type) => switch (type) {
        'issue'       => issueRed,
        'appreciation'=> appPurple,
        'update'      => updateBlue,
        _             => text2,
      };

  static Color tagBg(String type) => switch (type) {
        'issue'       => issueRedBg,
        'appreciation'=> appPurpleBg,
        'update'      => updateBlueBg,
        _             => const Color(0xFFF3F4F6),
      };

  static String tagLabel(String type) => switch (type) {
        'issue'       => 'Issue',
        'appreciation'=> 'Appreciation',
        'update'      => 'Update',
        _             => type,
      };

  static Color statusColor(String s) => switch (s) {
        'resolved'    => green,
        'in_progress' => updateBlue,
        'under_review'=> purple,
        'closed'      => text2,
        _             => const Color(0xFFF59E0B), // pending = amber
      };

  static String statusLabel(String s) => switch (s) {
        'pending'     => 'Reported',
        'under_review'=> 'Under Review',
        'in_progress' => 'In Progress',
        'resolved'    => 'Solved',
        'closed'      => 'Closed',
        _             => s,
      };
}
