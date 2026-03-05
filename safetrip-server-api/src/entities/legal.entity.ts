import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

/**
 * TB_USER_CONSENT — 사용자 동의 (도메인 I)
 * DB 설계 v3.5.1 §4.30
 */
@Entity('tb_user_consent')
@Index('idx_user_consent_user', ['userId'])
@Index('idx_user_consent_type', ['consentType', 'consentVersion'])
export class UserConsent {
    @PrimaryGeneratedColumn('increment', { name: 'consent_id', type: 'bigint' })
    consentId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'consent_type', type: 'varchar', length: 50 })
    consentType: string;
    // 'terms_of_service' | 'privacy_policy' | 'location_collection' |
    // 'lbs_terms' | 'international_transfer' | 'ai_data_usage' |
    // 'marketing' | 'minor_guardian' | 'location_third_party' | 'guardian_location_share'

    @Column({ name: 'consent_version', type: 'varchar', length: 20 })
    consentVersion: string;

    @Column({ name: 'is_agreed', type: 'boolean' })
    isAgreed: boolean;

    @Column({ name: 'agreed_at', type: 'timestamptz', nullable: true })
    agreedAt: Date | null;

    @Column({ name: 'withdrawn_at', type: 'timestamptz', nullable: true })
    withdrawnAt: Date | null;

    @Column({ name: 'guardian_user_id', type: 'varchar', length: 128, nullable: true })
    guardianUserId: string | null;

    @Column({ name: 'ip_address', type: 'varchar', length: 45, nullable: true })
    ipAddress: string | null;

    @Column({ name: 'device_info', type: 'jsonb', nullable: true })
    deviceInfo: any;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;
}

/**
 * TB_MINOR_CONSENT — 미성년자 동의 (도메인 I)
 * DB 설계 v3.5.1 §4.31
 */
@Entity('tb_minor_consent')
@Index('idx_minor_consent_user', ['userId'])
@Index('idx_minor_consent_guardian', ['guardianUserId'])
@Index('idx_minor_consent_school', ['b2bSchoolId'])
export class MinorConsent {
    @PrimaryGeneratedColumn('uuid', { name: 'consent_id' })
    consentId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'minor_status', type: 'varchar', length: 20 })
    minorStatus: string; // 'minor_child' | 'minor_under14' | 'minor_over14'

    @Column({ name: 'consent_type', type: 'varchar', length: 30 })
    consentType: string; // 'legal_guardian' | 'parent_notification' | 'b2b_school'

    @Column({ name: 'guardian_phone', type: 'varchar', length: 20, nullable: true })
    guardianPhone: string | null;

    @Column({ name: 'guardian_email', type: 'varchar', length: 255, nullable: true })
    guardianEmail: string | null;

    @Column({ name: 'guardian_user_id', type: 'varchar', length: 128, nullable: true })
    guardianUserId: string | null;

    @Column({ name: 'b2b_school_id', type: 'varchar', length: 128, nullable: true })
    b2bSchoolId: string | null;

    @Column({ name: 'b2b_contract_id', type: 'uuid', nullable: true })
    b2bContractId: string | null;

    @Column({ name: 'consent_items', type: 'jsonb', nullable: true })
    consentItems: any; // [{item, agreed, required}]

    @Column({ name: 'consented_at', type: 'timestamptz', nullable: true })
    consentedAt: Date | null;

    @Column({ name: 'consent_method', type: 'varchar', length: 20, nullable: true })
    consentMethod: string | null; // 'sms_auth' | 'email_auth' | 'b2b_csv' | 'offline_paper'

    @Column({ name: 'ip_address', type: 'varchar', length: 45, nullable: true })
    ipAddress: string | null;

    @Column({ name: 'expires_at', type: 'timestamptz', nullable: true })
    expiresAt: Date | null;

    @Column({ name: 'revoked_at', type: 'timestamptz', nullable: true })
    revokedAt: Date | null;

    @Column({ name: 'revoke_reason', type: 'text', nullable: true })
    revokeReason: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;
}

/**
 * TB_LOCATION_ACCESS_LOG — 위치정보 접근 이력 (도메인 I)
 * DB 설계 v3.5.1 §4.32
 */
@Entity('tb_location_access_log')
@Index('idx_loc_access_user', ['userId', 'createdAt'])
@Index('idx_loc_access_type', ['accessType'])
@Index('idx_loc_access_expired', ['expiredAt'])
export class LocationAccessLog {
    @PrimaryGeneratedColumn('increment', { name: 'log_id', type: 'bigint' })
    logId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'accessed_by_user_id', type: 'varchar', length: 128, nullable: true })
    accessedByUserId: string | null;

    @Column({ name: 'access_type', type: 'varchar', length: 30 })
    accessType: string;
    // 'realtime_view' | 'history_view' | 'sos_broadcast' |
    // 'geofence_alert' | 'guardian_snapshot' | 'guardian_request' |
    // 'attendance_check' | 'ai_analysis' | 'safety_guide'

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'location_data', type: 'jsonb', nullable: true })
    locationData: any;

    @Column({ name: 'access_purpose', type: 'varchar', length: 200, nullable: true })
    accessPurpose: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'expired_at', type: 'timestamptz', nullable: true })
    expiredAt: Date | null;
}

/**
 * TB_LOCATION_SHARING_PAUSE_LOG — 가디언 위치공유 일시중지 이력 (도메인 I)
 * DB 설계 v3.5.1 §4.33
 */
@Entity('tb_location_sharing_pause_log')
@Index('idx_pause_log_user', ['userId', 'tripId'])
export class LocationSharingPauseLog {
    @PrimaryGeneratedColumn('increment', { name: 'pause_log_id', type: 'bigint' })
    pauseLogId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'guardian_user_id', type: 'varchar', length: 128 })
    guardianUserId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'link_id', type: 'uuid', nullable: true })
    linkId: string | null;

    @Column({ name: 'privacy_level', type: 'varchar', length: 20 })
    privacyLevel: string;

    @Column({ name: 'pause_duration_hours', type: 'int' })
    pauseDurationHours: number;

    @Column({ name: 'max_allowed_hours', type: 'int' })
    maxAllowedHours: number;

    @Column({ name: 'paused_at', type: 'timestamptz' })
    pausedAt: Date;

    @Column({ name: 'resumed_at', type: 'timestamptz', nullable: true })
    resumedAt: Date | null;

    @Column({ name: 'resume_reason', type: 'varchar', length: 30, nullable: true })
    resumeReason: string | null;
    // 'auto_expire' | 'user_manual' | 'sos_override' | 'admin_override'

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}

/**
 * TB_DATA_DELETION_LOG — 데이터 삭제 이력 (도메인 I)
 * DB 설계 v3.5.1 §4.34
 */
@Entity('tb_data_deletion_log')
export class DataDeletionLog {
    @PrimaryGeneratedColumn('increment', { name: 'deletion_id', type: 'bigint' })
    deletionId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string; // No FK — preserved after user deletion

    @Column({ name: 'deletion_type', type: 'varchar', length: 30 })
    deletionType: string;
    // 'account_soft_delete' | 'account_hard_delete' |
    // 'location_batch_delete' | 'trip_data_delete' | 'consent_withdrawal'

    @Column({ name: 'affected_tables', type: 'text', array: true, nullable: true })
    affectedTables: string[] | null;

    @Column({ name: 'record_count', type: 'int', nullable: true })
    recordCount: number | null;

    @Column({ name: 'requested_by', type: 'varchar', length: 20, nullable: true })
    requestedBy: string | null; // 'user' | 'system' | 'admin'

    @CreateDateColumn({ name: 'executed_at', type: 'timestamptz' })
    executedAt: Date;

    @Column({ name: 'notes', type: 'text', nullable: true })
    notes: string | null;
}

/**
 * TB_DATA_PROVISION_LOG — 데이터 제공 이력 (도메인 I)
 * DB 설계 v3.5.1 §4.35
 */
@Entity('tb_data_provision_log')
export class DataProvisionLog {
    @PrimaryGeneratedColumn('uuid', { name: 'provision_id' })
    provisionId: string;

    @Column({ name: 'sos_event_id', type: 'uuid', nullable: true })
    sosEventId: string | null;

    @Column({ name: 'requesting_agency', type: 'varchar', length: 100, nullable: true })
    requestingAgency: string | null;

    @Column({ name: 'request_type', type: 'varchar', length: 30, nullable: true })
    requestType: string | null; // 'emergency_rescue' | 'warrant' | 'official_request'

    @Column({ name: 'legal_basis', type: 'text', nullable: true })
    legalBasis: string | null;

    @Column({ name: 'provided_items', type: 'jsonb', nullable: true })
    providedItems: any;

    @Column({ name: 'processed_by', type: 'varchar', length: 128, nullable: true })
    processedBy: string | null;

    @Column({ name: 'processed_by_user_id', type: 'varchar', length: 128, nullable: true })
    processedByUserId: string | null;

    @Column({ name: 'requested_at', type: 'timestamptz', nullable: true })
    requestedAt: Date | null;

    @Column({ name: 'provided_at', type: 'timestamptz', nullable: true })
    providedAt: Date | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}
