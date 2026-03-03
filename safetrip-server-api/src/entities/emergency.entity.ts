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
 * TB_EMERGENCY_CONTACT — 긴급 연락처 (도메인 F)
 * DB 설계 v3.4 §4.21a
 */
@Entity('tb_emergency_contact')
export class EmergencyContact {
    @PrimaryGeneratedColumn('uuid', { name: 'contact_id' })
    contactId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'contact_name', type: 'varchar', length: 50 })
    contactName: string;

    @Column({ name: 'phone_number', type: 'varchar', length: 20 })
    phoneNumber: string;

    @Column({ name: 'relationship', type: 'varchar', length: 30, nullable: true })
    relationship: string | null; // 'parent' | 'spouse' | 'friend' | 'colleague' | 'other'

    @Column({ name: 'priority', type: 'int', default: 0 })
    priority: number;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
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
