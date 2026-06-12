import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../config/gemini_config.dart';
import '../models/report_model.dart';

class GeminiService {
  // Classify a civic report into category, severity, and department
  Future<ReportClassification> classifyReport({
    required String description,
    Uint8List? imageBytes,
  }) async {
    final prompt = '''
You are a civic issue classifier for a government accountability platform.

Analyze this civic report and return a JSON response with:
- category: one of [infrastructure, environment, safety, public_service, appreciation, other]
- severity: one of [low, medium, high, critical]
- department: the most relevant government department
- tags: list of relevant keywords (max 5)
- summary: concise one-line summary

Report description: "$description"

Respond ONLY with valid JSON, no markdown.
''';

    GenerateContentResponse response;

    if (imageBytes != null) {
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ]),
      ];
      response = await GeminiConfig.visionModel.generateContent(content);
    } else {
      response = await GeminiConfig.flashModel.generateContent([
        Content.text(prompt),
      ]);
    }

    final json = _extractJson(response.text ?? '{}');
    return ReportClassification.fromJson(json);
  }

  // Generate AI-powered civic insight for a neighborhood
  Future<String> generateAreaInsight({
    required String areaName,
    required List<String> recentIssues,
    required int totalReports,
    required int resolvedReports,
  }) async {
    final resolutionRate = totalReports > 0
        ? (resolvedReports / totalReports * 100).toStringAsFixed(1)
        : '0';

    final prompt = '''
You are a civic analyst. Generate a brief, helpful insight (2-3 sentences) about
the civic health of "$areaName" based on this data:

- Total reports: $totalReports
- Resolved: $resolvedReports ($resolutionRate% resolution rate)
- Recent issues: ${recentIssues.join(', ')}

Be constructive, data-driven, and suggest one actionable improvement.
Keep it under 80 words.
''';

    final response = await GeminiConfig.flashModel.generateContent([
      Content.text(prompt),
    ]);
    return response.text ?? 'Unable to generate insight at this time.';
  }

  // Draft an official complaint letter from a report
  Future<String> draftComplaintLetter({
    required String reportTitle,
    required String description,
    required String location,
    required String department,
    required String citizenName,
  }) async {
    final prompt = '''
Draft a formal civic complaint letter to the $department department.

Details:
- Issue: $reportTitle
- Description: $description
- Location: $location
- Citizen: $citizenName
- Date: ${DateTime.now().toString().split(' ')[0]}

Write a professional, respectful letter under 200 words requesting prompt action.
Include subject line, salutation, body, and closing.
''';

    final response = await GeminiConfig.proModel.generateContent([
      Content.text(prompt),
    ]);
    return response.text ?? '';
  }

  // Moderate content to check if it's appropriate for civic platform
  Future<ContentModerationResult> moderateContent(String text) async {
    final prompt = '''
Review this civic platform submission for appropriateness.

Text: "$text"

Return JSON with:
- approved: boolean
- reason: brief explanation if not approved, null if approved
- edited_text: cleaned version if minor issues, null otherwise

Only flag if content is: spam, hate speech, personal attacks, or completely off-topic.
Respond ONLY with valid JSON.
''';

    final response = await GeminiConfig.flashModel.generateContent([
      Content.text(prompt),
    ]);
    final json = _extractJson(response.text ?? '{}');
    return ContentModerationResult.fromJson(json);
  }

  // Generate appreciation message suggestions
  Future<List<String>> suggestAppreciationMessages({
    required String officialName,
    required String achievement,
    required String role,
  }) async {
    final prompt = '''
Generate 3 short, genuine appreciation messages for a public official.

Official: $officialName ($role)
Achievement: $achievement

Each message should be:
- 1-2 sentences
- Specific and sincere
- Appropriate for a public platform

Return a JSON array of 3 strings only.
''';

    final response = await GeminiConfig.flashModel.generateContent([
      Content.text(prompt),
    ]);

    try {
      final json = _extractJson(response.text ?? '[]');
      return List<String>.from(json as List);
    } catch (_) {
      return [
        'Thank you for your dedicated service to our community.',
        'Your work on $achievement has made a real difference.',
        'We appreciate your commitment to improving our city.',
      ];
    }
  }

  Map<String, dynamic> _extractJson(String text) {
    final clean = text
        .replaceAll(RegExp(r'```json\n?'), '')
        .replaceAll(RegExp(r'```\n?'), '')
        .trim();
    return clean.isNotEmpty ? {} : {};
  }
}

class ContentModerationResult {
  final bool approved;
  final String? reason;
  final String? editedText;

  const ContentModerationResult({
    required this.approved,
    this.reason,
    this.editedText,
  });

  factory ContentModerationResult.fromJson(Map<String, dynamic> json) {
    return ContentModerationResult(
      approved: json['approved'] as bool? ?? true,
      reason: json['reason'] as String?,
      editedText: json['edited_text'] as String?,
    );
  }
}
