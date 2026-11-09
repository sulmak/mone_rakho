import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../models/notification_master.dart';
import '../reminder_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import 'calendar_tab.dart';
import 'entry_form_screen.dart';
import 'list_tab.dart';

/// Owns the shared NotificationMaster list + all add/edit/delete logic, and
/// switches between the List tab and the Calendar tab via a bottom nav bar.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  List<NotificationMaster> _entries = [];
  bool _loading = true;
  int _tabIndex = 0;
  bool _showAuthor = false; // "Author by" is hidden by default

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    FirestoreService.instance.stopListening();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await ReminderService.instance.init();
      await ReminderService.instance.requestPermissions();
    } catch (_) {}
    await _refresh();

    // Start real-time Firestore synchronization listener
    FirestoreService.instance.listen(
      onUpsert: (entry) async {
        await DatabaseHelper.instance.insert(entry);
        await ReminderService.instance.scheduleEntry(entry);
        if (mounted) {
          _refresh();
        }
      },
      onDelete: (id) async {
        await DatabaseHelper.instance.delete(id);
        await ReminderService.instance.cancelById(id);
        if (mounted) {
          _refresh();
        }
      },
    );
  }

  Future<void> _refresh() async {
    final entries = await DatabaseHelper.instance.getAll();
    // Keep every row's monthly alarm in sync with what's currently stored.
    await ReminderService.instance.rescheduleAll(entries);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _openForm(NotificationMaster? existing, {DateTime? prefillDate}) async {
    final maxSeq = _entries.fold<double>(0.0, (max, e) => (e.sequence ?? 0) > max ? (e.sequence ?? 0) : max);
    final nextSequence = maxSeq + 1.0;

    final result = await Navigator.of(context).push<NotificationMaster>(
      MaterialPageRoute(
        builder: (_) => EntryFormScreen(
          existing: existing,
          prefillDate: prefillDate,
          existingIds: _entries.map((e) => e.id).toList(),
          nextSequence: existing == null ? nextSequence : null,
        ),
      ),
    );
    if (result == null) return;

    if (existing == null) {
      await DatabaseHelper.instance.insert(result);
    } else {
      await DatabaseHelper.instance.update(result);
    }

    // Auto-create & sync to Firestore collection 'notifications'
    await FirestoreService.instance.save(result);

    // Schedule local repeating reminder for the exact target date/time
    await ReminderService.instance.scheduleEntry(result);

    await _refresh();
  }

  Future<void> _delete(NotificationMaster entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete notification?'),
        content: Text('This will remove "${entry.notification ?? entry.id}" and cancel its alarm.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    await FirestoreService.instance.delete(entry.id);
    await ReminderService.instance.cancelEntry(entry);
    await DatabaseHelper.instance.delete(entry.id);
    await _refresh();
  }

  Future<void> _testNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSenderEmail = prefs.getString('smtp_sender_email')?.trim().isNotEmpty == true 
        ? prefs.getString('smtp_sender_email')! 
        : 'sulmak.mridha@gmail.com';
    final savedSenderPassword = prefs.getString('smtp_app_password')?.trim().isNotEmpty == true 
        ? prefs.getString('smtp_app_password')! 
        : 'kvpg pilg hsdf ljf';

    final recipientController = TextEditingController();
    final senderEmailController = TextEditingController(text: savedSenderEmail);
    final senderPasswordController = TextEditingController(text: savedSenderPassword);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Test Notification & SMTP Email'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Triggers a local notification and sends an automatic SMTP email to another person.'),
              const SizedBox(height: 16),
              TextField(
                controller: recipientController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Recipient Email (Other Person)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Sender SMTP Settings (Gmail / App Password):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: senderEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Your Gmail / Sender Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: senderPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Gmail App Password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await prefs.setString('smtp_sender_email', senderEmailController.text.trim());
              await prefs.setString('smtp_app_password', senderPasswordController.text.trim());
              Navigator.pop(ctx, true);
            },
            child: const Text('Send & Test'),
          ),
        ],
      ),
    );

    if (result != true) return;
    if (!mounted) return;

    final email = recipientController.text.trim();
    final testEntry = NotificationMaster(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      notification: 'Test Notification from Mone Rakho!',
      email: email.isEmpty ? null : email,
      notificationDate: DateTime.now().add(const Duration(seconds: 2)),
      repeatType: RepeatType.monthly,
    );
    await ReminderService.instance.showNotificationNow(testEntry);
    String? emailError;
    if (email.isNotEmpty) {
      emailError = await ReminderService.instance.sendEmailWithResult(testEntry);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          email.isNotEmpty
              ? (emailError == null ? 'Notification sent & email sent to $email successfully!' : 'Email failed: $emailError')
              : 'Test notification sent!',
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      ListTab(
        entries: _entries,
        loading: _loading,
        onRefresh: _refresh,
        onOpenForm: (existing) => _openForm(existing),
        onDelete: _delete,
      ),
      CalendarTab(
        entries: _entries,
        onOpenForm: _openForm,
        onDelete: _delete,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 28, height: 28),
            const SizedBox(width: 10),
            const Text('Mone Rakho'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'User Profile & Sign Out',
            onPressed: () {
              final user = AuthService.instance.currentUser;
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('User Profile'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user != null ? 'Signed in as:\n${user.email}' : 'Running in Offline / Local Mode'),
                      const SizedBox(height: 16),
                      if (user != null) Text('UID: ${user.uid}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await AuthService.instance.signOut();
                        if (mounted) {
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Test Notification Now',
            onPressed: _testNotification,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'About',
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'Mone Rakho',
                applicationVersion: '2.0.0',
                applicationIcon: Image.asset('assets/images/logo.png', width: 48, height: 48),
                children: [
                  const SizedBox(height: 12),
                  const Text('Powered by Md. Atikur Rahman Mridha'),
                  Offstage(
                    offstage: !_showAuthor,
                    child: const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text('Author by Md. Atikur Rahman Mridha'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading && _tabIndex == 0 ? tabs[0] : tabs[_tabIndex],
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _showAuthor = !_showAuthor;
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Powered by Md. Atikur Rahman Mridha',
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  // Author by Md. Atikur Rahman Mridha (hidden by default)
                  Offstage(
                    offstage: !_showAuthor,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Text(
                        '• Author by Md. Atikur Rahman Mridha',
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'List'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'Calendar'),
        ],
      ),
      floatingActionButton: _tabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(null),
              icon: const Icon(Icons.add_alert),
              label: const Text('New Notification'),
            )
          : null,
    );
  }
}
