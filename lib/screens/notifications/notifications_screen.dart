import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../config/supabase_config.dart';

part 'notifications_screen.g.dart';

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String? type;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.type,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      type: json['type'] as String?,
    );
  }
}

@riverpod
Future<List<NotificationItem>> userNotifications(Ref ref) async {
  final userId = SupabaseConfig.client.auth.currentUser?.id;
  if (userId == null) return [];

  final data = await SupabaseConfig.client
      .from('notifications')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(50) as List<dynamic>;

  return data
      .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
      .toList();
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(userNotificationsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {/* TODO: mark all read */},
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 64,
                    color: colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications yet',
                    style: TextStyle(color: colorScheme.outline),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = notifications[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: n.isRead
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.primaryContainer,
                  child: Icon(
                    _iconForType(n.type),
                    color: n.isRead ? colorScheme.outline : colorScheme.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  n.title,
                  style: TextStyle(
                    fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      timeago.format(n.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                isThreeLine: true,
                tileColor: n.isRead ? null : colorScheme.primaryContainer.withOpacity(0.1),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconForType(String? type) => switch (type) {
    'report_update' => Icons.report_outlined,
    'appreciation' => Icons.star_outline,
    'resolution' => Icons.check_circle_outline,
    'comment' => Icons.comment_outlined,
    _ => Icons.notifications_outlined,
  };
}
