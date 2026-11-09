/// How an entry's alarm repeats.
enum RepeatType {
  monthly, // same day-of-month + time, every month (e.g. "pay VAT on the 1st")
  yearly; // same month + day + time, every year (e.g. birthdays, anniversaries)

  /// Stored in the DB as plain text so the column stays a simple VARCHAR,
  /// consistent with the rest of the schema.
  String get dbValue => this == RepeatType.yearly ? 'YEARLY' : 'MONTHLY';

  static RepeatType fromDbValue(String? value) {
    return value == 'YEARLY' ? RepeatType.yearly : RepeatType.monthly;
  }
}

/// Dart model mirroring the SQL Server table:
///
/// CREATE TABLE [NotificationMaster](
/// 	[Id] [VARCHAR](30) NOT NULL,
/// 	[Notification] NVARCHAR(1024) NULL,
///   [Email] VARCHAR(100) NULL,
/// 	[Sequence] [DECIMAL](18, 2) NULL,
/// 	[NotificationDate] [DATETIME] NULL,
/// 	[AddedBy] [VARCHAR](30) NULL,
/// 	[AddedDate] [DATETIME] NULL,
/// 	[UpdatedBy] [VARCHAR](30) NULL,
/// 	[UpdatedDate] [DATETIME] NULL,
///  PRIMARY KEY CLUSTERED ([Id] ASC)
/// )
class NotificationMaster {
  final String id; // VARCHAR(30), primary key
  final String? notification; // NVARCHAR(1024)
  final String? email; // VARCHAR(100)
  final double? sequence; // DECIMAL(18,2)
  final DateTime? notificationDate; // DATETIME — day+time the alarm fires
  final RepeatType repeatType; // extra column: MONTHLY or YEARLY
  final String? addedBy; // VARCHAR(30)
  final DateTime? addedDate; // DATETIME
  final String? updatedBy; // VARCHAR(30)
  final DateTime? updatedDate; // DATETIME

  const NotificationMaster({
    required this.id,
    this.notification,
    this.email,
    this.sequence,
    this.notificationDate,
    this.repeatType = RepeatType.monthly,
    this.addedBy,
    this.addedDate,
    this.updatedBy,
    this.updatedDate,
  });

  NotificationMaster copyWith({
    String? id,
    String? notification,
    String? email,
    double? sequence,
    DateTime? notificationDate,
    RepeatType? repeatType,
    String? addedBy,
    DateTime? addedDate,
    String? updatedBy,
    DateTime? updatedDate,
  }) {
    return NotificationMaster(
      id: id ?? this.id,
      notification: notification ?? this.notification,
      email: email ?? this.email,
      sequence: sequence ?? this.sequence,
      notificationDate: notificationDate ?? this.notificationDate,
      repeatType: repeatType ?? this.repeatType,
      addedBy: addedBy ?? this.addedBy,
      addedDate: addedDate ?? this.addedDate,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedDate: updatedDate ?? this.updatedDate,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'Id': id,
      'Notification': notification,
      'Email': email,
      'Sequence': sequence,
      'NotificationDate': notificationDate?.toIso8601String(),
      'RepeatType': repeatType.dbValue,
      'AddedBy': addedBy,
      'AddedDate': addedDate?.toIso8601String(),
      'UpdatedBy': updatedBy,
      'UpdatedDate': updatedDate?.toIso8601String(),
    };
  }

  factory NotificationMaster.fromMap(Map<String, Object?> map) {
    DateTime? parse(Object? v) => v == null ? null : DateTime.tryParse(v as String);
    return NotificationMaster(
      id: map['Id'] as String,
      notification: map['Notification'] as String?,
      email: map['Email'] as String?,
      sequence: (map['Sequence'] as num?)?.toDouble(),
      notificationDate: parse(map['NotificationDate']),
      repeatType: RepeatType.fromDbValue(map['RepeatType'] as String?),
      addedBy: map['AddedBy'] as String?,
      addedDate: parse(map['AddedDate']),
      updatedBy: map['UpdatedBy'] as String?,
      updatedDate: parse(map['UpdatedDate']),
    );
  }

  /// A stable 32-bit integer derived from [id], used as the Android
  /// notification/alarm id (flutter_local_notifications needs an int id,
  /// our primary key is a VARCHAR).
  int get notificationIntId => id.hashCode & 0x7FFFFFFF;
}
