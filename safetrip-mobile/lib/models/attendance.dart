class AttendanceCheck {

  AttendanceCheck({
    required this.id,
    required this.tripId,
    required this.status,
    required this.createdAt,
  });

  factory AttendanceCheck.fromJson(Map<String, dynamic> json) {
    return AttendanceCheck(
      id: json['id'] as String? ?? json['check_id'] as String? ?? json['checkId'] as String? ?? '',
      tripId: json['trip_id'] as String? ?? json['tripId'] as String? ?? '',
      status: AttendanceStatusExtension.fromString(json['status'] as String?),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : (json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now()),
    );
  }
  final String id;
  final String tripId;
  final AttendanceStatus status;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AttendanceCheck copyWith({
    String? id,
    String? tripId,
    AttendanceStatus? status,
    DateTime? createdAt,
  }) {
    return AttendanceCheck(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum AttendanceStatus {
  ongoing,
  completed,
  cancelled,
}

extension AttendanceStatusExtension on AttendanceStatus {
  static AttendanceStatus fromString(String? status) {
    switch (status) {
      case 'completed':
        return AttendanceStatus.completed;
      case 'cancelled':
        return AttendanceStatus.cancelled;
      case 'ongoing':
      default:
        return AttendanceStatus.ongoing;
    }
  }
}

class AttendanceResponse {

  AttendanceResponse({
    required this.checkId,
    required this.memberId,
    required this.responseType,
    required this.respondedAt,
  });

  factory AttendanceResponse.fromJson(Map<String, dynamic> json) {
    return AttendanceResponse(
      checkId: json['check_id'] as String? ?? json['checkId'] as String? ?? '',
      memberId: json['member_id'] as String? ?? json['memberId'] as String? ?? '',
      responseType: AttendanceResponseTypeExtension.fromString(json['response_type'] as String? ?? json['responseType'] as String?),
      respondedAt: json['responded_at'] != null ? DateTime.parse(json['responded_at']) : (json['respondedAt'] != null ? DateTime.parse(json['respondedAt']) : DateTime.now()),
    );
  }
  final String checkId;
  final String memberId;
  final AttendanceResponseType responseType;
  final DateTime respondedAt;

  Map<String, dynamic> toJson() {
    return {
      'check_id': checkId,
      'member_id': memberId,
      'response_type': responseType.toString().split('.').last,
      'responded_at': respondedAt.toIso8601String(),
    };
  }

  AttendanceResponse copyWith({
    String? checkId,
    String? memberId,
    AttendanceResponseType? responseType,
    DateTime? respondedAt,
  }) {
    return AttendanceResponse(
      checkId: checkId ?? this.checkId,
      memberId: memberId ?? this.memberId,
      responseType: responseType ?? this.responseType,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }
}

enum AttendanceResponseType {
  present,
  absent,
  unknown,
}

extension AttendanceResponseTypeExtension on AttendanceResponseType {
  static AttendanceResponseType fromString(String? type) {
    switch (type) {
      case 'present':
        return AttendanceResponseType.present;
      case 'absent':
        return AttendanceResponseType.absent;
      case 'unknown':
      default:
        return AttendanceResponseType.unknown;
    }
  }
}
