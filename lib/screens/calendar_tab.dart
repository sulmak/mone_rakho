import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/notification_master.dart';

/// The "Calendar" tab. A day is marked whenever an entry recurs onto it:
/// monthly entries match on day-of-month alone (so the dot reappears every
/// month); yearly entries (birthdays, anniversaries) match on month+day
/// (so the dot only reappears once a year, on the right month). Tapping a
/// day lists the entries that fire on it.
class CalendarTab extends StatefulWidget {
  final List<NotificationMaster> entries;
  final void Function(NotificationMaster? existing, {DateTime? prefillDate}) onOpenForm;
  final void Function(NotificationMaster entry) onDelete;

  const CalendarTab({
    super.key,
    required this.entries,
    required this.onOpenForm,
    required this.onDelete,
  });

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  List<NotificationMaster> _entriesForDay(DateTime day) {
    return widget.entries
        .where((e) {
          final d = e.notificationDate;
          if (d == null) return false;
          if (e.repeatType == RepeatType.yearly) {
            return d.month == day.month && d.day == day.day;
          }
          return d.day == day.day;
        })
        .toList()
      ..sort((a, b) => (a.sequence ?? 0).compareTo(b.sequence ?? 0));
  }

  @override
  Widget build(BuildContext context) {
    final selectedEntries = _entriesForDay(_selectedDay);

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(12),
          child: TableCalendar<NotificationMaster>(
            firstDay: DateTime.utc(2015, 1, 1),
            lastDay: DateTime.utc(2100, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            eventLoader: _entriesForDay,
            calendarFormat: CalendarFormat.month,
            availableCalendarFormats: const {CalendarFormat.month: 'Month'},
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Color(0x336200EE),
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Color(0xFF6200EE),
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Color(0xFF03DAC5),
                shape: BoxShape.circle,
              ),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
                _selectedDay = focusedDay;
              });
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE, MMMM d').format(_selectedDay),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              TextButton.icon(
                onPressed: () => widget.onOpenForm(null, prefillDate: _selectedDay),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add here'),
              ),
            ],
          ),
        ),
        Expanded(
          child: selectedEntries.isEmpty
              ? Center(
                  child: Text(
                    'Nothing scheduled on ${DateFormat('MMMM d').format(_selectedDay)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: selectedEntries.length,
                  itemBuilder: (context, index) {
                    final entry = selectedEntries[index];
                    final time = entry.notificationDate != null
                        ? DateFormat('h:mm a').format(entry.notificationDate!)
                        : '';
                    final isYearly = entry.repeatType == RepeatType.yearly;
                    final recurrenceLabel = isYearly
                        ? 'Every year on ${DateFormat('MMM d').format(entry.notificationDate!)}'
                        : 'Every month on day ${entry.notificationDate!.day}';
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          isYearly ? Icons.cake_outlined : Icons.notifications_active,
                          color: const Color(0xFF6200EE),
                        ),
                        title: Text(entry.notification?.isNotEmpty == true ? entry.notification! : '(no message)'),
                        subtitle: Text('$recurrenceLabel • $time'),
                        onTap: () => widget.onOpenForm(entry),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => widget.onDelete(entry),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
