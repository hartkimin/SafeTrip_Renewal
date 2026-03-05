import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

/**
 * TB_B2B_ORGANIZATION — B2B 조직 (도메인 J)
 * DB 설계 v3.4 §4.30
 */
@Entity('tb_b2b_organization')
export class B2bOrganization {
    @PrimaryGeneratedColumn('uuid', { name: 'org_id' })
    orgId: string;

    @Column({ name: 'org_name', type: 'varchar', length: 200 })
    orgName: string;

    @Column({ name: 'org_type', type: 'varchar', length: 30 })
    orgType: string; // 'school' | 'corporate' | 'agency' | 'government'

    @Column({ name: 'business_number', type: 'varchar', length: 20, nullable: true })
    businessNumber: string | null;

    @Column({ name: 'contact_name', type: 'varchar', length: 50, nullable: true })
    contactName: string | null;

    @Column({ name: 'contact_email', type: 'varchar', length: 200, nullable: true })
    contactEmail: string | null;

    @Column({ name: 'contact_phone', type: 'varchar', length: 20, nullable: true })
    contactPhone: string | null;

    @Column({ name: 'is_active', type: 'boolean', default: true })
    isActive: boolean;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}

/**
 * TB_B2B_CONTRACT — B2B 계약 (도메인 L)
 * DB 설계 v3.5.1 §4.43
 */
@Entity('tb_b2b_contract')
@Index('idx_b2b_contract_type', ['contractType'])
@Index('idx_b2b_contract_status', ['status'])
export class B2bContract {
    @PrimaryGeneratedColumn('uuid', { name: 'contract_id' })
    contractId: string;

    @Column({ name: 'contract_code', type: 'varchar', length: 20, unique: true, nullable: true })
    contractCode: string | null;

    @Column({ name: 'contract_type', type: 'varchar', length: 20, nullable: true })
    contractType: string | null; // 'school' | 'corporate' | 'travel_agency' | 'insurance'

    @Column({ name: 'company_name', type: 'varchar', length: 200, nullable: true })
    companyName: string | null;

    @Column({ name: 'contact_name', type: 'varchar', length: 100, nullable: true })
    contactName: string | null;

    @Column({ name: 'contact_email', type: 'varchar', length: 255, nullable: true })
    contactEmail: string | null;

    @Column({ name: 'contact_phone', type: 'varchar', length: 20, nullable: true })
    contactPhone: string | null;

    @Column({ name: 'max_groups', type: 'int', default: 1 })
    maxGroups: number;

    @Column({ name: 'max_members_per_group', type: 'int', default: 50 })
    maxMembersPerGroup: number;

    @Column({ name: 'max_trips', type: 'int', nullable: true })
    maxTrips: number | null;

    @Column({ name: 'guardian_model', type: 'varchar', length: 20, default: 'A' })
    guardianModel: string; // 'A' (individual consent) | 'B' (bulk)

    @Column({ name: 'sla_level', type: 'varchar', length: 20, default: 'standard' })
    slaLevel: string; // 'standard' | 'premium' | 'enterprise'

    @Column({ name: 'started_at', type: 'date', nullable: true })
    startedAt: Date | null;

    @Column({ name: 'expires_at', type: 'date', nullable: true })
    expiresAt: Date | null;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'active' })
    status: string; // 'active' | 'suspended' | 'expired'

    @Column({ name: 'school_id', type: 'uuid', nullable: true })
    schoolId: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;

    // -- Backward-compat columns (from old B2bContract schema) --
    @Column({ name: 'org_id', type: 'uuid', nullable: true, select: false })
    orgId: string | null;

    @Column({ name: 'contract_name', type: 'varchar', length: 200, nullable: true, select: false })
    contractName: string | null;

    @Column({ name: 'start_date', type: 'date', nullable: true, select: false })
    startDate: Date | null;

    @Column({ name: 'end_date', type: 'date', nullable: true, select: false })
    endDate: Date | null;

    @Column({ name: 'max_members', type: 'int', nullable: true, select: false })
    maxMembers: number | null;

    @Column({ name: 'current_trip_count', type: 'int', nullable: true, select: false })
    currentTripCount: number | null;

    @Column({ name: 'forced_privacy_level', type: 'varchar', length: 30, nullable: true, select: false })
    forcedPrivacyLevel: string | null;

    @Column({ name: 'forced_sharing_mode', type: 'varchar', length: 20, nullable: true, select: false })
    forcedSharingMode: string | null;
}

/**
 * TB_B2B_ADMIN — B2B 관리자 (도메인 J)
 * DB 설계 v3.4 §4.32
 */
@Entity('tb_b2b_admin')
export class B2bAdmin {
    @PrimaryGeneratedColumn('uuid', { name: 'admin_id' })
    adminId: string;

    @Column({ name: 'org_id', type: 'uuid' })
    orgId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'admin_role', type: 'varchar', length: 20, default: 'org_admin' })
    adminRole: string; // 'org_admin' | 'trip_manager' | 'viewer'

    @Column({ name: 'is_active', type: 'boolean', default: true })
    isActive: boolean;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}

/**
 * TB_B2B_DASHBOARD_CONFIG — B2B 대시보드 설정 (도메인 J, v3.2 신규)
 * DB 설계 v3.4 §4.33
 */
@Entity('tb_b2b_dashboard_config')
export class B2bDashboardConfig {
    @PrimaryGeneratedColumn('uuid', { name: 'config_id' })
    configId: string;

    @Column({ name: 'org_id', type: 'uuid' })
    orgId: string;

    @Column({ name: 'contract_id', type: 'uuid', nullable: true })
    contractId: string | null;

    @Column({ name: 'config_key', type: 'varchar', length: 100 })
    configKey: string;

    @Column({ name: 'config_value', type: 'jsonb' })
    configValue: any;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;
}

/**
 * TB_B2B_SCHOOL — 학교 정보 (도메인 L)
 * DB 설계 v3.5.1 §4.44
 */
@Entity('tb_b2b_school')
export class B2bSchool {
    @PrimaryGeneratedColumn('uuid', { name: 'school_id' })
    schoolId: string;

    @Column({ name: 'school_name', type: 'varchar', length: 200 })
    schoolName: string;

    @Column({ name: 'school_code', type: 'varchar', length: 50, nullable: true })
    schoolCode: string | null;

    @Column({ name: 'region', type: 'varchar', length: 100, nullable: true })
    region: string | null;

    @Column({ name: 'district', type: 'varchar', length: 100, nullable: true })
    district: string | null;

    @Column({ name: 'school_type', type: 'varchar', length: 20, nullable: true })
    schoolType: string | null; // 'elementary' | 'middle' | 'high' | 'university'

    @Column({ name: 'contact_teacher', type: 'varchar', length: 100, nullable: true })
    contactTeacher: string | null;

    @Column({ name: 'contact_phone', type: 'varchar', length: 20, nullable: true })
    contactPhone: string | null;

    @Column({ name: 'contact_email', type: 'varchar', length: 255, nullable: true })
    contactEmail: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;
}

/**
 * TB_B2B_INVITE_BATCH — B2B 일괄 초대 (도메인 L)
 * DB 설계 v3.5.1 §4.45
 */
@Entity('tb_b2b_invite_batch')
@Index('idx_b2b_invite_batch_contract', ['contractId'])
export class B2bInviteBatch {
    @PrimaryGeneratedColumn('uuid', { name: 'batch_id' })
    batchId: string;

    @Column({ name: 'contract_id', type: 'uuid' })
    contractId: string;

    @Column({ name: 'group_id', type: 'uuid', nullable: true })
    groupId: string | null;

    @Column({ name: 'batch_name', type: 'varchar', length: 200, nullable: true })
    batchName: string | null;

    @Column({ name: 'target_role', type: 'varchar', length: 30 })
    targetRole: string; // 'crew' | 'guardian'

    @Column({ name: 'total_count', type: 'int' })
    totalCount: number;

    @Column({ name: 'used_count', type: 'int', default: 0 })
    usedCount: number;

    @Column({ name: 'csv_file_url', type: 'text', nullable: true })
    csvFileUrl: string | null;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'active' })
    status: string; // 'active' | 'expired' | 'cancelled'

    @Column({ name: 'created_by', type: 'varchar', length: 128, nullable: true })
    createdBy: string | null;

    @Column({ name: 'expires_at', type: 'timestamptz', nullable: true })
    expiresAt: Date | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;
}

/**
 * TB_B2B_MEMBER_LOG — B2B 멤버 참여 기록 (도메인 L)
 * DB 설계 v3.5.1 §4.46
 */
@Entity('tb_b2b_member_log')
export class B2bMemberLog {
    @PrimaryGeneratedColumn('uuid', { name: 'log_id' })
    logId: string;

    @Column({ name: 'batch_id', type: 'uuid' })
    batchId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128, nullable: true })
    userId: string | null;

    @Column({ name: 'invite_code', type: 'varchar', length: 7, nullable: true })
    inviteCode: string | null;

    @Column({ name: 'joined_at', type: 'timestamptz', nullable: true })
    joinedAt: Date | null;

    @Column({ name: 'member_role', type: 'varchar', length: 30, nullable: true })
    memberRole: string | null;

    @Column({ name: 'minor_consent_id', type: 'uuid', nullable: true })
    minorConsentId: string | null;

    @Column({ name: 'notes', type: 'text', nullable: true })
    notes: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}
