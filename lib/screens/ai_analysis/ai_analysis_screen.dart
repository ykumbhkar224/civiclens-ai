import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../services/gemini_service.dart';

part 'ai_analysis_screen.g.dart';

@riverpod
Future<String> areaInsight(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  final city = user?.userMetadata?['city'] as String? ?? 'your city';

  final reports = await ref.watch(myReportsProvider.future);
  final resolved = reports.where((r) => r.status.name == 'resolved').length;
  final issueTypes = reports.map((r) => r.category.name).toSet().toList();

  return ref.read(geminiServiceProvider).generateAreaInsight(
    areaName: city,
    recentIssues: issueTypes,
    totalReports: reports.length,
    resolvedReports: resolved,
  );
}

class AiAnalysisScreen extends ConsumerWidget {
  const AiAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightAsync = ref.watch(areaInsightProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Civic Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(areaInsightProvider),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // AI insight card
          Card(
            color: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Neighborhood Insight',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  insightAsync.when(
                    loading: () => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ShimmerLine(width: double.infinity),
                        const SizedBox(height: 8),
                        _ShimmerLine(width: 260),
                        const SizedBox(height: 8),
                        _ShimmerLine(width: 200),
                      ],
                    ),
                    error: (e, _) => Text(
                      'Unable to generate insight. Tap refresh to try again.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                    data: (insight) => Text(
                      insight,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Feature cards
          Text(
            'AI-Powered Features',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _FeatureCard(
            icon: Icons.category_outlined,
            title: 'Smart Classification',
            description:
                'AI automatically categorises your reports, suggests the right department, and sets severity based on your description.',
            color: colorScheme.secondaryContainer,
          ),
          _FeatureCard(
            icon: Icons.document_scanner_outlined,
            title: 'Complaint Letter Drafting',
            description:
                'Generate a formal complaint letter for any issue with one tap — ready to submit to the department.',
            color: colorScheme.tertiaryContainer,
          ),
          _FeatureCard(
            icon: Icons.shield_outlined,
            title: 'Content Moderation',
            description:
                'All submissions are reviewed by AI to maintain a respectful and productive civic platform.',
            color: colorScheme.errorContainer,
          ),
          _FeatureCard(
            icon: Icons.star_outline,
            title: 'Appreciation Suggestions',
            description:
                'AI crafts personalised, genuine appreciation messages for public officials based on their achievements.',
            color: colorScheme.primaryContainer,
          ),

          const SizedBox(height: 20),
          Text(
            'Coming Soon',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...[
            'Trend analysis across neighbourhoods',
            'Predicted resolution time for issues',
            'Department performance scoring',
            'Civic policy summarisation',
          ].map(
            (item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.pending_outlined, color: colorScheme.outline),
              title: Text(item, style: textTheme.bodyMedium),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerLine extends StatelessWidget {
  final double width;
  const _ShimmerLine({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 14,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        borderRadius: BorderRadius.circular(7),
      ),
    );
  }
}
