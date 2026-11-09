import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_master.dart';

/// Add / edit screen for a single NotificationMaster row with Email support.
class EntryFormScreen extends StatefulWidget {
  final NotificationMaster? existing;

  /// When adding a new entry from the Calendar tab's "Add here" action,
  /// this pre-fills the date picker with the day that was tapped.
  final DateTime? prefillDate;

  /// Existing entry IDs in the database to prevent ID collision on creation.
  final List<String> existingIds;

  /// Auto-generated unique sequence number for new entries.
  final double? nextSequence;

  const EntryFormScreen({
    super.key,
    this.existing,
    this.prefillDate,
    this.existingIds = const [],
    this.nextSequence,
  });

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _notificationController;
  late final TextEditingController _emailController;
  late final TextEditingController _sequenceController;
  DateTime _notificationDate = DateTime.now();
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);
  RepeatType _repeatType = RepeatType.monthly;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _idController = TextEditingController(text: e?.id ?? const Uuid().v4().substring(0, 8));
    _notificationController = TextEditingController(text: e?.notification ?? '');
    _emailController = TextEditingController(text: e?.email ?? '');
    final seq = e?.sequence ?? widget.nextSequence ?? 1.0;
    _sequenceController = TextEditingController(
      text: seq.toStringAsFixed(0),
    );
    _repeatType = e?.repeatType ?? RepeatType.monthly;
    if (e?.notificationDate != null) {
      _notificationDate = e!.notificationDate!;
      _notificationTime = TimeOfDay(hour: _notificationDate.hour, minute: _notificationDate.minute);
    } else if (widget.prefillDate != null) {
      _notificationDate = widget.prefillDate!;
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _notificationController.dispose();
    _emailController.dispose();
    _sequenceController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _notificationDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _notificationDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
    );
    if (picked != null) {
      setState(() => _notificationTime = picked);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final combinedDate = DateTime(
      _notificationDate.year,
      _notificationDate.month,
      _notificationDate.day,
      _notificationTime.hour,
      _notificationTime.minute,
    );

    final now = DateTime.now();
    final result = NotificationMaster(
      id: _idController.text.trim(),
      notification: _notificationController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      sequence: double.tryParse(_sequenceController.text.trim()),
      notificationDate: combinedDate,
      repeatType: _repeatType,
      addedBy: widget.existing?.addedBy ?? 'user',
      addedDate: widget.existing?.addedDate ?? now,
      updatedBy: _isEditing ? 'user' : null,
      updatedDate: _isEditing ? now : null,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isYearly = _repeatType == RepeatType.yearly;
    final dateLabel = DateFormat(isYearly ? 'MMMM d' : 'EEEE, MMM d, yyyy').format(_notificationDate);
    final timeLabel = _notificationTime.format(context);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Notification' : 'New Notification')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              controller: _idController,
              enabled: !_isEditing,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'Id *',
                helperText: 'Unique key (VARCHAR 30). Auto-filled, editable before saving.',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Id is required';
                }
                final id = v.trim();
                if (!_isEditing && widget.existingIds.contains(id)) {
                  return 'This Id is already in use. Please enter a unique Id.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notificationController,
              maxLength: 1024,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notification message *',
                hintText: isYearly ? 'e.g. "Rafiq\'s birthday" or "Our anniversary"' : 'e.g. "filling the vat"',
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Message is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address (optional)',
                hintText: 'e.g. recipient@example.com',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v != null && v.trim().isNotEmpty && !v.contains('@')) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sequenceController,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Sequence',
                helperText: 'Auto-generated unique sequence number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Repeats', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<RepeatType>(
              segments: const [
                ButtonSegment(
                  value: RepeatType.monthly,
                  label: Text('Monthly'),
                  icon: Icon(Icons.repeat),
                ),
                ButtonSegment(
                  value: RepeatType.yearly,
                  label: Text('Yearly'),
                  icon: Icon(Icons.cake_outlined),
                ),
              ],
              selected: {_repeatType},
              onSelectionChanged: (selection) {
                setState(() => _repeatType = selection.first);
              },
            ),
            const SizedBox(height: 16),
            Text(
              isYearly
                  ? 'Every year on this month & day — perfect for birthdays, anniversaries, etc.'
                  : 'Every month on this day — perfect for bills, rent, recurring filings, etc.',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(dateLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(timeLabel),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
