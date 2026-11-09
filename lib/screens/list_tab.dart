import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/notification_master.dart';
import '../reminder_service.dart';

/// The "List" tab: every NotificationMaster row, sorted by Sequence, with
/// its next monthly occurrence. Tap to edit, trash icon to delete.
class ListTab extends StatelessWidget {
  final List<NotificationMaster> entries;
  final bool loading;
  final Future<void> Function() onRefresh;
  final void Function(NotificationMaster? existing) onOpenForm;
  final void Function(NotificationMaster entry) onDelete;

  const ListTab({
    super.key,
    required this.entries,
    required this.loading,
    required this.onRefresh,
    required this.onOpenForm,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (entries.isEmpty) {
      return _EmptyState(onAdd: () => onOpenForm(null));
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final next = entry.notificationDate != null
              ? ReminderService.instance.nextOccurrenceFor(entry)
              : null;
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF6200EE),
                foregroundColor: Colors.white,
                child: entry.repeatType == RepeatType.yearly
                    ? const Icon(Icons.cake_outlined, size: 18)
                    : Text(
                        entry.sequence != null ? entry.sequence!.toStringAsFixed(0) : '•',
                        style: const TextStyle(fontSize: 13),
                      ),
              ),
              title: Text(entry.notification?.isNotEmpty == true ? entry.notification! : '(no message)'),
              subtitle: Text(
                next != null
                    ? '${entry.repeatType == RepeatType.yearly ? 'Repeats yearly' : 'Repeats monthly'} • next: ${DateFormat('MMM d, yyyy h:mm a').format(next)}'
                    : 'No date set',
              ),
              onTap: () => onOpenForm(entry),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onDelete(entry),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', width: 100, height: 100),
            const SizedBox(height: 24),
            const Text(
              'No notifications yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add an entry with a message and a date — choose monthly\n(bills, filings) or yearly (birthdays, anniversaries), and\nit repeats automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add your first notification'),
            ),
          ],
        ),
      ),
    );
  }
}
