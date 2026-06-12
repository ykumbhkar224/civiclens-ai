import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/report_model.dart';
import '../../providers/report_provider.dart';

class ReportDetailScreen extends ConsumerStatefulWidget {
  final String reportId;
  const ReportDetailScreen({super.key, required this.reportId});

  @override
  ConsumerState<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends ConsumerState<ReportDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(reportDetailProvider(widget.reportId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {/* TODO: share */},
          ),
        ],
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (report) => _ReportDetailView(report: report),
      ),
    );
  }
}

class _ReportDetailView extends ConsumerWidget {
  final ReportModel report;
  const _ReportDetailView({required this.report});

  Color _severityColor(BuildContext context, ReportSeverity severity) {
    final cs = Theme.of(context).colorScheme;
    return switch (severity) {
      ReportSeverity.low => Colors.green,
      ReportSeverity.medium => Colors.orange,
      ReportSeverity.high => cs.error,
      ReportSeverity.critical => Colors.purple,
    };
  }

  Color _statusColor(BuildContext context, ReportStatus status) {
    return switch (status) {
      ReportStatus.pending => Colors.grey,
      ReportStatus.under_review => Colors.blue,
      ReportStatus.in_progress => Colors.orange,
      ReportStatus.resolved => Colors.green,
      ReportStatus.closed => Colors.red,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Images
        if (report.imageUrls.isNotEmpty) ...[
          SizedBox(
            height: 200,
            child: PageView.builder(
              itemCount: report.imageUrls.length,
              itemBuilder: (context, i) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  report.imageUrls[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Status & Severity chips
        Row(
          children: [
            Chip(
              label: Text(report.status.name.replaceAll('_', ' ').toUpperCase()),
              backgroundColor:
                  _statusColor(context, report.status).withOpacity(0.15),
              labelStyle: TextStyle(
                color: _statusColor(context, report.status),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text(report.severity.name.toUpperCase()),
              backgroundColor:
                  _severityColor(context, report.severity).withOpacity(0.15),
              labelStyle: TextStyle(
                color: _severityColor(context, report.severity),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
            const Spacer(),
            Icon(Icons.thumb_up_outlined, size: 16, color: colorScheme.outline),
            const SizedBox(width: 4),
            Text(
              '${report.upvoteCount}',
              style: textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 12),

        Text(report.title, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.location_on_outlined, size: 16, color: colorScheme.outline),
            const SizedBox(width: 4),
            Expanded(
              child: Text(report.address, style: textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.schedule_outlined, size: 16, color: colorScheme.outline),
            const SizedBox(width: 4),
            Text(
              timeago.format(report.createdAt),
              style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 12),

        Text('Description', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(report.description, style: textTheme.bodyMedium),

        // AI Summary
        if (report.aiSummary != null && report.aiSummary!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            color: colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: colorScheme.secondary),
                      const SizedBox(width: 6),
                      Text('AI Summary', style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(report.aiSummary!, style: textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],

        // Tags
        if (report.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: report.tags.map((tag) => Chip(label: Text('#$tag'), labelStyle: textTheme.labelSmall)).toList(),
          ),
        ],

        // Department
        if (report.department != null) ...[
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.business_outlined),
            title: const Text('Assigned Department'),
            subtitle: Text(report.department!),
          ),
        ],

        // Official Response
        if (report.officialResponse != null) ...[
          const SizedBox(height: 16),
          Card(
            color: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 6),
                      Text('Official Response', style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(report.officialResponse!, style: textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => ref.read(reportServiceProvider).upvoteReport(report.id),
          icon: const Icon(Icons.thumb_up_outlined),
          label: const Text('Upvote this issue'),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
