import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class Schedule {
  Schedule({
    required this.scheduleId,
    this.tripId,
    this.groupId,
    required this.createdBy,
    required this.title,
    this.description,
    required this.scheduleType,
    this.locationName,
    this.locationAddress,
    this.locationCoords,
    required this.startTime,
    this.endTime,
    this.allDay = false,
    this.scheduleDate,
    this.participants,
    this.estimatedCost,
    this.currencyCode,
    this.bookingReference,
    this.bookingStatus,
    this.bookingUrl,
    this.reminderEnabled = true,
    this.reminderTime,
    this.attachments,
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.timezone,
    this.geofenceId,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    try {
      tz.initializeTimeZones();
    } catch (e) {
      // Ignore
    }

    DateTime parseWithTimezone(String timeString, String? timezone) {
      final parsed = DateTime.parse(timeString);
      if (timezone == null || timezone.isEmpty) {
        return parsed.isUtc ? parsed.toLocal() : parsed;
      }

      try {
        final utcTime = parsed.isUtc ? parsed : parsed.toUtc();
        final location = tz.getLocation(timezone);
        final tzTime = tz.TZDateTime.fromMillisecondsSinceEpoch(
          location,
          utcTime.millisecondsSinceEpoch,
        );

        return DateTime(
          tzTime.year,
          tzTime.month,
          tzTime.day,
          tzTime.hour,
          tzTime.minute,
          tzTime.second,
          tzTime.millisecond,
          tzTime.microsecond,
        );
      } catch (e) {
        return parsed.isUtc ? parsed.toLocal() : parsed;
      }
    }

    final timezone = json['timezone'] as String?;

    return Schedule(
      scheduleId: json['travel_schedule_id']?.toString() ?? json['schedule_id']?.toString() ?? json['scheduleId']?.toString() ?? '',
      tripId: json['trip_id'] as String? ?? json['tripId'] as String?,
      groupId: json['group_id'] as String? ?? json['groupId'] as String?,
      createdBy: json['created_by'] as String? ?? json['createdBy'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      scheduleType: json['schedule_type'] as String? ?? json['scheduleType'] as String? ?? 'other',
      locationName: json['location_name'] as String? ?? json['locationName'] as String?,
      locationAddress: json['location_address'] as String? ?? json['locationAddress'] as String?,
      locationCoords: (json['location_lat'] != null && json['location_lng'] != null)
          ? {'latitude': (json['location_lat'] as num).toDouble(), 'longitude': (json['location_lng'] as num).toDouble()}
          : (json['location_coords'] != null
              ? Map<String, double>.from(
                  (json['location_coords'] as Map).map(
                    (key, value) =>
                        MapEntry(key as String, (value as num).toDouble()),
                  ),
                )
              : (json['locationCoords'] != null
                  ? Map<String, double>.from(json['locationCoords'] as Map)
                  : null)),
      startTime: json['start_time'] != null ? parseWithTimezone(json['start_time'] as String, timezone) : DateTime.now(),
      endTime: json['end_time'] != null
          ? parseWithTimezone(json['end_time'] as String, timezone)
          : null,
      allDay: json['all_day'] as bool? ?? json['allDay'] as bool? ?? false,
      scheduleDate: json['schedule_date'] as String?,
      participants: json['participants'] != null
          ? List<Map<String, dynamic>>.from(json['participants'] as List)
          : null,
      estimatedCost: json['estimated_cost'] != null
          ? (json['estimated_cost'] as num).toDouble()
          : null,
      currencyCode: json['currency_code'] as String?,
      bookingReference: json['booking_reference'] as String?,
      bookingStatus: json['booking_status'] as String?,
      bookingUrl: json['booking_url'] as String?,
      reminderEnabled: json['reminder_enabled'] as bool? ?? true,
      reminderTime: json['reminder_time'] as int?,
      attachments: json['attachments'] != null
          ? List<Map<String, dynamic>>.from(json['attachments'] as List)
          : null,
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] != null
          ? parseWithTimezone(json['completed_at'] as String, timezone)
          : null,
      createdAt: json['created_at'] != null ? parseWithTimezone(json['created_at'] as String, timezone) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? parseWithTimezone(json['updated_at'] as String, timezone) : DateTime.now(),
      deletedAt: json['deleted_at'] != null
          ? parseWithTimezone(json['deleted_at'] as String, timezone)
          : null,
      timezone: timezone,
      geofenceId: json['geofence_id'] as String? ?? json['geofenceId'] as String?,
    );
  }

  final String scheduleId;
  final String? tripId;
  final String? groupId;
  final String createdBy;
  final String title;
  final String? description;
  final String scheduleType;
  final String? locationName;
  final String? locationAddress;
  final Map<String, double>? locationCoords;
  final DateTime startTime;
  final DateTime? endTime;
  final bool allDay;
  final String? scheduleDate;
  final List<Map<String, dynamic>>? participants;
  final double? estimatedCost;
  final String? currencyCode;
  final String? bookingReference;
  final String? bookingStatus;
  final String? bookingUrl;
  final bool reminderEnabled;
  final int? reminderTime;
  final List<Map<String, dynamic>>? attachments;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final String? timezone;
  final String? geofenceId;

  Map<String, dynamic> toJson() {
    return {
      'schedule_id': scheduleId,
      'trip_id': tripId,
      'group_id': groupId,
      'created_by': createdBy,
      'title': title,
      'description': description,
      'schedule_type': scheduleType,
      'location_name': locationName,
      'location_address': locationAddress,
      'location_coords': locationCoords,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'all_day': allDay,
      'schedule_date': scheduleDate,
      'participants': participants,
      'estimated_cost': estimatedCost,
      'currency_code': currencyCode,
      'booking_reference': bookingReference,
      'booking_status': bookingStatus,
      'booking_url': bookingUrl,
      'reminder_enabled': reminderEnabled,
      'reminder_time': reminderTime,
      'attachments': attachments,
      'is_completed': isCompleted,
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
      'timezone': timezone,
      'geofence_id': geofenceId,
    };
  }

  Schedule copyWith({
    String? scheduleId,
    String? tripId,
    String? groupId,
    String? createdBy,
    String? title,
    String? description,
    String? scheduleType,
    String? locationName,
    String? locationAddress,
    Map<String, double>? locationCoords,
    DateTime? startTime,
    DateTime? endTime,
    bool? allDay,
    String? scheduleDate,
    List<Map<String, dynamic>>? participants,
    double? estimatedCost,
    String? currencyCode,
    String? bookingReference,
    String? bookingStatus,
    String? bookingUrl,
    bool? reminderEnabled,
    int? reminderTime,
    List<Map<String, dynamic>>? attachments,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    String? timezone,
    String? geofenceId,
  }) {
    return Schedule(
      scheduleId: scheduleId ?? this.scheduleId,
      tripId: tripId ?? this.tripId,
      groupId: groupId ?? this.groupId,
      createdBy: createdBy ?? this.createdBy,
      title: title ?? this.title,
      description: description ?? this.description,
      scheduleType: scheduleType ?? this.scheduleType,
      locationName: locationName ?? this.locationName,
      locationAddress: locationAddress ?? this.locationAddress,
      locationCoords: locationCoords ?? this.locationCoords,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      allDay: allDay ?? this.allDay,
      scheduleDate: scheduleDate ?? this.scheduleDate,
      participants: participants ?? this.participants,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      currencyCode: currencyCode ?? this.currencyCode,
      bookingReference: bookingReference ?? this.bookingReference,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      bookingUrl: bookingUrl ?? this.bookingUrl,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      attachments: attachments ?? this.attachments,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      timezone: timezone ?? this.timezone,
      geofenceId: geofenceId ?? this.geofenceId,
    );
  }
}
