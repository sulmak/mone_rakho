# Mone Rakho — Flutter

**Powered by Mone Rakho**
<!-- Author by Md. Atikur Rahman Mridha -->

**Mone Rakho** (মনে রাখো — Bengali for "remember this") is a Flutter/Dart Android app
where **you manage your own list of reminders** instead of one hardcoded message. Each
entry is a row in a local `NotificationMaster` table — add, edit, or delete them from
the app — and every entry gets its own **repeating notification + alarm**, either:
- **Monthly** — same day-of-month + time, every month (bills, filings, rent), or
- **Yearly** — same month + day + time, every year (birthdays, anniversaries)

You choose which when adding or editing an entry.

Two ways to view your reminders, switchable from the bottom menu:
- **List** — every entry, sorted by Sequence, tagged Monthly or Yearly, with its next
  firing date.
- **Calendar** — a month calendar (like a calendar-event view). Days with a scheduled
  reminder show a dot; tap any day to see what's on it and add a new entry straight
  onto that day. Monthly entries show a dot every month; yearly entries only show it
  on their one month/day each year — both update automatically as you browse months.

## The data model

The local SQLite table mirrors your SQL Server schema, plus one extra column:

```sql
CREATE TABLE NotificationMaster (
    Id               VARCHAR(30)   NOT NULL PRIMARY KEY,
    Notification     NVARCHAR(1024),
    Sequence         DECIMAL(18,2),
    NotificationDate DATETIME,
    RepeatType       VARCHAR(10),   -- 'MONTHLY' or 'YEARLY' (added for this feature)
    AddedBy          VARCHAR(30),
    AddedDate        DATETIME,
    UpdatedBy        VARCHAR(30),
    UpdatedDate      DATETIME
)
```

- **Id** — primary key; auto-suggested (editable) when you add a new entry.
- **Notification** — the reminder message shown in the notification.
- **Sequence** — controls display order in the list (lower = higher up).
- **NotificationDate** — pick a date + time in the app.
  - Monthly entries use the **day-of-month** and **time**.
  - Yearly entries use the **month**, **day**, and **time**.
- **RepeatType** — `MONTHLY` or `YEARLY`; set via the Monthly/Yearly toggle in the form.
- **AddedBy / AddedDate / UpdatedBy / UpdatedDate** — filled in automatically by the app.

This is stored **on-device** (SQLite via `sqflite`), fully offline — no server needed.
If you later want this synced with a real SQL Server backend, apply the same column
there too:
```sql
ALTER TABLE NotificationMaster ADD RepeatType VARCHAR(10) NULL DEFAULT 'MONTHLY'
```

## How scheduling works
- Every row with a `NotificationDate` gets its own Android alarm via
  `flutter_local_notifications`:
  - Monthly → `matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime`
  - Yearly → `matchDateTimeComponents: DateTimeComponents.dateAndTime` (matches
    month/day/hour/minute, ignores year — fires once a year)
- A date that doesn't exist every period is clamped: the 31st in a 30-day month fires
  on the 30th; a Feb 29 birthday fires on Feb 28 in non-leap years.
- Alarms persist across phone reboots (the plugin re-arms them automatically), and the
  app also re-syncs every entry's alarm against the database each time it opens.
- Each entry's Android notification/alarm id is derived from its `Id`, so editing or
  deleting a row correctly replaces/cancels that row's own alarm, not another one's.
- Existing installs upgrade automatically: the database adds the `RepeatType` column
  on first launch of this version and treats any existing entries as Monthly (their
  original behavior), nothing is lost.

## The logo
A purple calendar card with a teal bell badge — ties the two ideas (scheduled dates +
notifications) together. It's used as the Android launcher icon and inside the app
(app bar and empty state). Say if you'd like a different style, color, or a
monogram/initials version instead.

## Prerequisites
- Flutter SDK: https://docs.flutter.dev/get-started/install (`flutter doctor` to verify)
- Android Studio or a physical Android phone with USB debugging enabled.

## How to run it
```bash
flutter pub get
flutter run
```
(or open the folder in Android Studio with the Flutter/Dart plugins installed, pick
your device, and press Run ▶)

On first launch the app asks for notification permission and (Android 12+) exact-alarm
permission — allow both so reminders fire reliably and on time.

To build a standalone APK:
```bash
flutter build apk --release
```
APK lands at `build/app/outputs/flutter-apk/app-release.apk`.

## Using the app
1. Tap **New Notification** (List tab) or **Add here** on a selected day (Calendar tab).
2. Enter a message (e.g. "filling the vat" or "Rafiq's birthday"), optionally a
   sequence number, choose **Monthly** or **Yearly**, and pick the date/time.
3. Save — it's now in your list and scheduled to repeat.
4. Tap any entry to edit it, or the trash icon to delete it (cancels its alarm too).

## Project structure
```
mone_rakho/
  lib/
    main.dart                      — app entry point / theme
    reminder_service.dart          — schedules/cancels monthly or yearly alarms per entry
    models/notification_master.dart — Dart model matching the SQL table (+ RepeatType)
    db/database_helper.dart        — local SQLite CRUD + v1→v2 migration for RepeatType
    screens/
      root_shell.dart              — bottom-nav shell, owns the shared entry list
      list_tab.dart                — the List view
      calendar_tab.dart            — the Calendar view
      entry_form_screen.dart       — add/edit form (message, sequence, repeat type, date/time)
  assets/images/logo.png           — app logo
  android/
    app/src/main/AndroidManifest.xml
    app/src/main/kotlin/.../MainActivity.kt
```

## Customizing
- Want some entries to fire **once** instead of repeating? In
  `reminder_service.dart`'s `scheduleEntry`, drop `matchDateTimeComponents` from the
  `zonedSchedule` call for that entry and it'll fire a single time at the exact
  `notificationDate` instead of repeating.
- Want a different recurrence (weekly, specific weekday, every N days)? That's a
  different `matchDateTimeComponents` value / custom scheduling loop — ask and I can
  add it as a third `RepeatType` option.

## Note on the email address from earlier
Same as before — this is a phone notification/alarm, not an email. Flutter apps can't
send email on their own without a backend. Say the word if you'd like a scheduled
cloud function added that also emails you when entries are due.
