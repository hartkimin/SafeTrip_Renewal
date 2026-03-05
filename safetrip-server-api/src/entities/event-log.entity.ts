import { Entity, Column, PrimaryGeneratedColumn, CreateDateColumn, Index } from 'typeorm';

/**
 * TB_EVENT_LOG — 이벤트 기록 (도메인 J)
 * DB 설계 v3.5.1 §4.36
 */
@Entity('tb_event_log')
@Index('idx_event_log_group', ['groupId'])
@Index('idx_event_log_type', ['eventType'])
export class EventLog {
    @PrimaryGeneratedColumn('uuid', { name: 'event_id' })
    eventId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128, nullable: true })
    userId: string | null;

    @Column({ name: 'group_id', type: 'uuid', nullable: true })
    groupId: string | null;

    @Column({ name: 'event_type', type: 'varchar', length: 50 })
    eventType: string;
    // 'SOS' | 'geofence_enter' | 'geofence_exit' | 'attendance' |
    // 'member_joined' | 'member_left' | 'member_removed' |
    // 'role_changed' | 'leader_transferred' | 'schedule_modified' |
    // 'guardian_linked' | 'guardian_unlinked' | 'guardian_paused' |
    // 'movement_start' | 'movement_end' | 'route_deviation'

    @Column({ name: 'movement_session_id', type: 'uuid', nullable: true })
    movementSessionId: string | null;

    @Column({ name: 'event_data', type: 'jsonb', nullable: true })
    eventData: any;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    // -- Backward-compat columns (used by existing code) --

    @Column({ name: 'event_subtype', type: 'varchar', length: 50, nullable: true, select: false })
    eventSubtype: string | null;

    @Column({ name: 'latitude', type: 'decimal', precision: 10, scale: 7, nullable: true, select: false })
    latitude: number | null;

    @Column({ name: 'longitude', type: 'decimal', precision: 10, scale: 7, nullable: true, select: false })
    longitude: number | null;

    @Column({ name: 'address', type: 'text', nullable: true, select: false })
    address: string | null;

    @Column({ name: 'battery_level', type: 'int', nullable: true, select: false })
    batteryLevel: number | null;

    @Column({ name: 'battery_is_charging', type: 'boolean', nullable: true, select: false })
    batteryIsCharging: boolean | null;

    @Column({ name: 'network_type', type: 'varchar', length: 20, nullable: true, select: false })
    networkType: string | null;

    @Column({ name: 'app_version', type: 'varchar', length: 20, nullable: true, select: false })
    appVersion: string | null;

    @Column({ name: 'geofence_id', type: 'uuid', nullable: true, select: false })
    geofenceId: string | null;

    @Column({ name: 'location_id', type: 'uuid', nullable: true, select: false })
    locationId: string | null;

    @Column({ name: 'sos_id', type: 'uuid', nullable: true, select: false })
    sosId: string | null;

    @Column({ name: 'occurred_at', type: 'timestamptz', nullable: true, select: false })
    occurredAt: Date | null;
}

/**
 * TB_LEADER_TRANSFER_LOG — 리더 이양 기록 (도메인 J)
 * DB 설계 v3.5.1 §4.37
 */
@Entity('tb_leader_transfer_log')
export class LeaderTransferLog {
    @PrimaryGeneratedColumn('uuid', { name: 'transfer_id' })
    transferId: string;

    @Column({ name: 'group_id', type: 'uuid', nullable: true })
    groupId: string | null;

    @Column({ name: 'from_user_id', type: 'varchar', length: 128, nullable: true })
    fromUserId: string | null;

    @Column({ name: 'to_user_id', type: 'varchar', length: 128, nullable: true })
    toUserId: string | null;

    @CreateDateColumn({ name: 'transferred_at', type: 'timestamptz' })
    transferredAt: Date;

    @Column({ name: 'from_user_new_role', type: 'varchar', length: 30, default: 'crew_chief' })
    fromUserNewRole: string;
}

/**
 * TB_EMERGENCY_NUMBER — 긴급 전화번호 DB (도메인 J)
 * DB 설계 v3.5.1 §4.38
 */
@Entity('tb_emergency_number')
@Index('idx_emergency_number_country', ['countryCode'])
@Index('idx_emergency_number_type', ['numberType'])
export class EmergencyNumber {
    @PrimaryGeneratedColumn('uuid', { name: 'number_id' })
    numberId: string;

    @Column({ name: 'country_code', type: 'varchar', length: 5 })
    countryCode: string;

    @Column({ name: 'number_type', type: 'varchar', length: 20 })
    numberType: string; // 'general' | 'police' | 'fire' | 'ambulance' | 'coast_guard'

    @Column({ name: 'phone_number', type: 'varchar', length: 30 })
    phoneNumber: string;

    @Column({ name: 'phone_number_intl', type: 'varchar', length: 30, nullable: true })
    phoneNumberIntl: string | null;

    @Column({ name: 'display_name_ko', type: 'varchar', length: 100, nullable: true })
    displayNameKo: string | null;

    @Column({ name: 'display_name_en', type: 'varchar', length: 100, nullable: true })
    displayNameEn: string | null;

    @Column({ name: 'display_name_local', type: 'varchar', length: 100, nullable: true })
    displayNameLocal: string | null;

    @Column({ name: 'description', type: 'text', nullable: true })
    description: string | null;

    @Column({ name: 'is_primary', type: 'boolean', default: false })
    isPrimary: boolean;

    @Column({ name: 'is_free_call', type: 'boolean', default: true })
    isFreeCall: boolean;

    @Column({ name: 'available_24h', type: 'boolean', default: true })
    available24h: boolean;

    @Column({ name: 'notes', type: 'text', nullable: true })
    notes: string | null;

    @Column({ name: 'source', type: 'varchar', length: 20, nullable: true })
    source: string | null; // 'manual' | 'mofa_api' | 'external'

    @Column({ name: 'verified_at', type: 'timestamptz', nullable: true })
    verifiedAt: Date | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;
}
