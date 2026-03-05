import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

/**
 * TB_EMERGENCY — 긴급 상황 (도메인 F)
 * DB 설계 v3.4 §4.21
 */
@Entity('tb_emergency')
@Index('idx_emergency_trip', ['tripId'])
@Index('idx_emergency_user', ['userId'])
export class Emergency {
    @PrimaryGeneratedColumn('uuid', { name: 'emergency_id' })
    emergencyId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'emergency_type', type: 'varchar', length: 30 })
    emergencyType: string; // 'sos' | 'no_response' | 'geofence_violation' | 'manual'

    @Column({ name: 'severity', type: 'varchar', length: 20, default: 'medium' })
    severity: string; // 'low' | 'medium' | 'high' | 'critical'

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'active' })
    status: string; // 'active' | 'acknowledged' | 'resolved' | 'false_alarm'

    @Column({ name: 'latitude', type: 'float', nullable: true })
    latitude: number | null;

    @Column({ name: 'longitude', type: 'float', nullable: true })
    longitude: number | null;

    @Column({ name: 'description', type: 'text', nullable: true })
    description: string | null;

    @Column({ name: 'acknowledged_by', type: 'varchar', length: 128, nullable: true })
    acknowledgedBy: string | null;

    @Column({ name: 'acknowledged_at', type: 'timestamptz', nullable: true })
    acknowledgedAt: Date | null;

    @Column({ name: 'resolved_by', type: 'varchar', length: 128, nullable: true })
    resolvedBy: string | null;

    @Column({ name: 'resolved_at', type: 'timestamptz', nullable: true })
    resolvedAt: Date | null;

    @Column({ name: 'resolution_note', type: 'text', nullable: true })
    resolutionNote: string | null;

    /** v3.4: 에스컬레이션 관련 */
    @Column({ name: 'escalation_level', type: 'int', default: 0 })
    escalationLevel: number;

    @Column({ name: 'last_escalated_at', type: 'timestamptz', nullable: true })
    lastEscalatedAt: Date | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}

/**
 * TB_EMERGENCY_CONTACT -- 긴급 연락처 (도메인 A)
 * DB 설계 v3.5.1 $4.2
 */
@Entity('tb_emergency_contact')
export class EmergencyContact {
    @PrimaryGeneratedColumn('uuid', { name: 'contact_id' })
    contactId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'contact_name', type: 'varchar', length: 100 })
    contactName: string;

    @Column({ name: 'phone_number', type: 'varchar', length: 20 })
    phoneNumber: string;

    @Column({ name: 'phone_country_code', type: 'varchar', length: 5, nullable: true })
    phoneCountryCode: string | null;

    @Column({ name: 'relationship', type: 'varchar', length: 20, nullable: true })
    relationship: string | null; // 'parent' | 'spouse' | 'sibling' | 'friend' | 'other'

    @Column({ name: 'sort_order', type: 'int', default: 0 })
    priority: number; // TypeScript: priority, DB column: sort_order (SSOT name)

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;
}

/**
 * TB_EMERGENCY_RECIPIENT — 긴급 상황 수신자 (도메인 F, 구 TB_SOS_RECIPIENT)
 * DB 설계 v3.4 §4.22b — 수신자별 알림 상태 및 응답 추적
 */
@Entity('tb_emergency_recipient')
@Index('idx_emergency_recipient_emergency', ['emergencyId'])
@Index('idx_emergency_recipient_user', ['userId'])
export class EmergencyRecipient {
    @PrimaryGeneratedColumn('uuid', { name: 'recipient_id' })
    recipientId: string;

    @Column({ name: 'emergency_id', type: 'uuid' })
    emergencyId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'recipient_type', type: 'varchar', length: 20 })
    recipient_type: string; // 'guardian' | 'group_member' | 'emergency_contact'

    /** 전송 채널 상태 (JSONB: { push: 'sent', sms: 'failed', email: 'pending' }) */
    @Column({ name: 'channels', type: 'jsonb', nullable: true })
    channels: any;

    @Column({ name: 'is_acknowledged', type: 'boolean', default: false })
    isAcknowledged: boolean;

    @Column({ name: 'acknowledged_at', type: 'timestamptz', nullable: true })
    acknowledgedAt: Date | null;

    @Column({ name: 'response_message', type: 'text', nullable: true })
    responseMessage: string | null;

    @CreateDateColumn({ name: 'sent_at', type: 'timestamptz' })
    sentAt: Date;
}

/**
 * TB_SOS_EVENT — SOS 이벤트 (도메인 F)
 * DB 설계 v3.4 §4.22
 */
@Entity('tb_sos_event')
export class SosEvent {
    @PrimaryGeneratedColumn('uuid', { name: 'sos_id' })
    sosId: string;

    @Column({ name: 'emergency_id', type: 'uuid' })
    emergencyId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'latitude', type: 'float' })
    latitude: number;

    @Column({ name: 'longitude', type: 'float' })
    longitude: number;

    @Column({ name: 'trigger_method', type: 'varchar', length: 20 })
    triggerMethod: string; // 'button' | 'gesture' | 'auto'

    @Column({ name: 'countdown_seconds', type: 'int', default: 10 })
    countdownSeconds: number;

    @Column({ name: 'was_cancelled', type: 'boolean', default: false })
    wasCancelled: boolean;

    @CreateDateColumn({ name: 'triggered_at', type: 'timestamptz' })
    triggeredAt: Date;

    @Column({ name: 'sent_at', type: 'timestamptz', nullable: true })
    sentAt: Date | null;
}

/**
 * TB_NO_RESPONSE_EVENT — 무응답 이벤트 (도메인 F)
 * DB 설계 v3.4 §4.22a
 */
@Entity('tb_no_response_event')
export class NoResponseEvent {
    @PrimaryGeneratedColumn('uuid', { name: 'no_response_id' })
    noResponseId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'check_type', type: 'varchar', length: 30 })
    checkType: string; // 'periodic' | 'admin_manual'

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'waiting' })
    status: string; // 'waiting' | 'responded' | 'escalated' | 'resolved'

    @Column({ name: 'threshold_minutes', type: 'int', default: 30 })
    thresholdMinutes: number;

    @CreateDateColumn({ name: 'check_started_at', type: 'timestamptz' })
    checkStartedAt: Date;

    @Column({ name: 'responded_at', type: 'timestamptz', nullable: true })
    respondedAt: Date | null;
}

/**
 * TB_SAFETY_CHECKIN — 안전 체크인 (도메인 F, v3.5 신규)
 * DB 설계 v3.5 §4.23
 */
@Entity('tb_safety_checkin')
@Index('idx_safety_checkins_user', ['userId'])
@Index('idx_safety_checkins_trip', ['tripId'])
@Index('idx_safety_checkins_created', ['createdAt'])
export class SafetyCheckin {
    @PrimaryGeneratedColumn('uuid', { name: 'checkin_id' })
    checkinId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'location_id', type: 'uuid', nullable: true })
    locationId: string | null;

    @Column({ name: 'checkin_type', type: 'varchar', length: 20 })
    checkinType: string; // 'manual' | 'guardian_request' | 'scheduled' | 'auto'

    @Column({ name: 'latitude', type: 'decimal', precision: 10, scale: 8, nullable: true })
    latitude: number | null;

    @Column({ name: 'longitude', type: 'decimal', precision: 11, scale: 8, nullable: true })
    longitude: number | null;

    @Column({ name: 'address', type: 'text', nullable: true })
    address: string | null;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'safe' })
    status: string; // 'safe' | 'need_help' | 'no_response'

    @Column({ name: 'message', type: 'text', nullable: true })
    message: string | null;

    @Column({ name: 'battery_level', type: 'int', nullable: true })
    batteryLevel: number | null;

    @Column({ name: 'network_type', type: 'varchar', length: 20, nullable: true })
    networkType: string | null;

    @Column({ name: 'requested_by_user_id', type: 'varchar', length: 128, nullable: true })
    requestedByUserId: string | null;

    @Column({ name: 'requested_at', type: 'timestamptz', nullable: true })
    requestedAt: Date | null;

    @Column({ name: 'visibility', type: 'varchar', length: 20, default: 'all' })
    visibility: string; // 'private' | 'guardians' | 'group' | 'all'

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}

/**
 * TB_HEARTBEAT — 생존 신호 (도메인 F)
 * DB 설계 v3.5.1 §4.18
 */
@Entity('tb_heartbeat')
@Index('idx_heartbeat_user', ['userId', 'timestamp'])
@Index('idx_heartbeat_trip', ['tripId', 'timestamp'])
export class Heartbeat {
    @PrimaryGeneratedColumn('increment', { name: 'id', type: 'bigint' })
    id: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'timestamp', type: 'timestamptz' })
    timestamp: Date;

    @Column({ name: 'location_lat', type: 'decimal', nullable: true })
    locationLat: number | null;

    @Column({ name: 'location_lng', type: 'decimal', nullable: true })
    locationLng: number | null;

    @Column({ name: 'battery_level', type: 'int', nullable: true })
    batteryLevel: number | null;

    @Column({ name: 'battery_charging', type: 'boolean', nullable: true })
    batteryCharging: boolean | null;

    @Column({ name: 'network_type', type: 'varchar', length: 10, nullable: true })
    networkType: string | null; // 'wifi' | '4g' | '5g' | 'none'

    @Column({ name: 'app_state', type: 'varchar', length: 20, nullable: true })
    appState: string | null; // 'foreground' | 'background' | 'doze'

    @Column({ name: 'motion_state', type: 'varchar', length: 20, nullable: true })
    motionState: string | null; // 'moving' | 'stationary' | 'unknown'
}

/**
 * TB_POWER_EVENT — 전원 이벤트 (도메인 F)
 * DB 설계 v3.5.1 §4.20
 */
@Entity('tb_power_event')
export class PowerEvent {
    @PrimaryGeneratedColumn('increment', { name: 'id', type: 'bigint' })
    id: string;

    @Column({ name: 'event_type', type: 'varchar', length: 20 })
    eventType: string; // 'LAST_BEACON' | 'SHUTDOWN' | 'POWER_RECOVERY'

    @Column({ name: 'user_id', type: 'varchar', length: 128, nullable: true })
    userId: string | null;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'location_lat', type: 'decimal', nullable: true })
    locationLat: number | null;

    @Column({ name: 'location_lng', type: 'decimal', nullable: true })
    locationLng: number | null;

    @Column({ name: 'battery_level', type: 'int', nullable: true })
    batteryLevel: number | null;

    @Column({ name: 'offline_duration_min', type: 'int', nullable: true })
    offlineDurationMin: number | null;

    @Column({ name: 'timestamp', type: 'timestamptz' })
    timestamp: Date;
}

/**
 * TB_SOS_RESCUE_LOG — 구조 연동 기록 (도메인 F)
 * DB 설계 v3.5.1 §4.21
 */
@Entity('tb_sos_rescue_log')
export class SosRescueLog {
    @PrimaryGeneratedColumn('uuid', { name: 'rescue_log_id' })
    rescueLogId: string;

    @Column({ name: 'sos_event_id', type: 'uuid' })
    sosEventId: string;

    @Column({ name: 'group_id', type: 'uuid', nullable: true })
    groupId: string | null;

    @Column({ name: 'user_id', type: 'varchar', length: 128, nullable: true })
    userId: string | null;

    @Column({ name: 'action_type', type: 'varchar', length: 30 })
    actionType: string;
    // 'dial_police' | 'dial_ambulance' | 'dial_fire' |
    // 'dial_embassy' | 'dial_consular' | 'copy_location' | 'sms_fallback'

    @Column({ name: 'target_number', type: 'varchar', length: 30, nullable: true })
    targetNumber: string | null;

    @Column({ name: 'target_country', type: 'varchar', length: 5, nullable: true })
    targetCountry: string | null;

    @Column({ name: 'initiated_by', type: 'varchar', length: 128, nullable: true })
    initiatedBy: string | null;

    @Column({ name: 'is_proxy_report', type: 'boolean', default: false })
    isProxyReport: boolean;

    @Column({ name: 'location_shared', type: 'boolean', default: false })
    locationShared: boolean;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}

/**
 * TB_SOS_CANCEL_LOG — SOS 해제 기록 (도메인 F)
 * DB 설계 v3.5.1 §4.22
 */
@Entity('tb_sos_cancel_log')
export class SosCancelLog {
    @PrimaryGeneratedColumn('uuid', { name: 'cancel_log_id' })
    cancelLogId: string;

    @Column({ name: 'sos_event_id', type: 'uuid' })
    sosEventId: string;

    @Column({ name: 'group_id', type: 'uuid', nullable: true })
    groupId: string | null;

    @Column({ name: 'cancelled_by', type: 'varchar', length: 128, nullable: true })
    cancelledBy: string | null;

    @Column({ name: 'cancel_reason', type: 'varchar', length: 30, nullable: true })
    cancelReason: string | null; // 'user_cancelled' | 'captain_cancelled' | 'auto_resolved'

    @Column({ name: 'cancel_within_sec', type: 'int', nullable: true })
    cancelWithinSec: number | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}
