import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/appreciation_model.dart';
import '../../providers/appreciation_provider.dart';
import '../../services/gemini_service.dart';

class AppreciationScreen extends ConsumerWidget {
  const AppreciationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Appreciate'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Officials', icon: Icon(Icons.people_outline)),
              Tab(text: 'Feed', icon: Icon(Icons.feed_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OfficialsTab(),
            _FeedTab(),
          ],
        ),
      ),
    );
  }
}

class _OfficialsTab extends ConsumerWidget {
  const _OfficialsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final officialsAsync = ref.watch(officialsProvider());

    return officialsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (officials) {
        if (officials.isEmpty) {
          return const Center(child: Text('No officials registered yet'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: officials.length,
          itemBuilder: (context, i) => _OfficialCard(official: officials[i]),
        );
      },
    );
  }
}

class _OfficialCard extends ConsumerWidget {
  final PublicOfficialModel official;
  const _OfficialCard({required this.official});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: official.avatarUrl != null
                      ? NetworkImage(official.avatarUrl!)
                      : null,
                  child: official.avatarUrl == null
                      ? Text(
                          official.name[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        official.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${official.role} — ${official.department}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                  icon: Icons.star,
                  label: '${official.appreciationCount} appreciations',
                  color: Colors.amber,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  icon: Icons.check_circle,
                  label: '${official.resolvedIssues} resolved',
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => _showAppreciationDialog(context, ref, official),
              child: const Text('Send Appreciation'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppreciationDialog(
    BuildContext context,
    WidgetRef ref,
    PublicOfficialModel official,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AppreciationBottomSheet(official: official),
    );
  }
}

class _AppreciationBottomSheet extends ConsumerStatefulWidget {
  final PublicOfficialModel official;
  const _AppreciationBottomSheet({required this.official});

  @override
  ConsumerState<_AppreciationBottomSheet> createState() =>
      _AppreciationBottomSheetState();
}

class _AppreciationBottomSheetState
    extends ConsumerState<_AppreciationBottomSheet> {
  final _messageController = TextEditingController();
  final _achievementController = TextEditingController();
  List<String> _aiSuggestions = [];
  bool _loadingSuggestions = false;

  @override
  void dispose() {
    _messageController.dispose();
    _achievementController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() => _loadingSuggestions = true);
    final gemini = ref.read(geminiServiceProvider);
    final suggestions = await gemini.suggestAppreciationMessages(
      officialName: widget.official.name,
      achievement: _achievementController.text.isNotEmpty
          ? _achievementController.text
          : 'public service',
      role: widget.official.role,
    );
    if (mounted) {
      setState(() {
        _aiSuggestions = suggestions;
        _loadingSuggestions = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_messageController.text.trim().isEmpty) return;
    await ref.read(submitAppreciationNotifierProvider.notifier).submit(
      toOfficialId: widget.official.id,
      officialName: widget.official.name,
      officialRole: widget.official.role,
      message: _messageController.text.trim(),
      achievement: _achievementController.text.trim().isNotEmpty
          ? _achievementController.text.trim()
          : null,
      department: widget.official.department,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final submitState = ref.watch(submitAppreciationNotifierProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Appreciate ${widget.official.name}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _achievementController,
            decoration: const InputDecoration(
              labelText: 'Achievement (optional)',
              hintText: 'What did they do well?',
              prefixIcon: Icon(Icons.emoji_events_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Your message',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.message_outlined),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadingSuggestions ? null : _loadSuggestions,
            icon: _loadingSuggestions
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: const Text('AI Suggestions'),
          ),
          if (_aiSuggestions.isNotEmpty)
            Column(
              children: _aiSuggestions.map((s) => ListTile(
                dense: true,
                leading: const Icon(Icons.tips_and_updates_outlined, size: 18),
                title: Text(s, style: Theme.of(context).textTheme.bodySmall),
                onTap: () => setState(() => _messageController.text = s),
              )).toList(),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: submitState.isLoading ? null : _submit,
            child: submitState.isLoading
                ? const CircularProgressIndicator()
                : const Text('Send Appreciation'),
          ),
        ],
      ),
    );
  }
}

class _FeedTab extends ConsumerWidget {
  const _FeedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(recentAppreciationsProvider());

    return feedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (appreciations) {
        if (appreciations.isEmpty) {
          return const Center(child: Text('No appreciations yet. Be the first!'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: appreciations.length,
          itemBuilder: (context, i) => _AppreciationCard(appreciation: appreciations[i]),
        );
      },
    );
  }
}

class _AppreciationCard extends ConsumerWidget {
  final AppreciationModel appreciation;
  const _AppreciationCard({required this.appreciation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    appreciation.officialName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  timeago.format(appreciation.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(appreciation.message, style: Theme.of(context).textTheme.bodyMedium),
            if (appreciation.achievement != null) ...[
              const SizedBox(height: 6),
              Chip(
                label: Text(appreciation.achievement!),
                avatar: const Icon(Icons.emoji_events_outlined, size: 16),
                labelStyle: Theme.of(context).textTheme.labelSmall,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.thumb_up_outlined, size: 16, color: colorScheme.outline),
                const SizedBox(width: 4),
                Text('${appreciation.likeCount}', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () => ref
                      .read(appreciationServiceProvider)
                      .likeAppreciation(appreciation.id),
                  icon: const Icon(Icons.thumb_up_outlined, size: 16),
                  label: const Text('Like'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: Theme.of(context).textTheme.labelSmall),
      visualDensity: VisualDensity.compact,
    );
  }
}
