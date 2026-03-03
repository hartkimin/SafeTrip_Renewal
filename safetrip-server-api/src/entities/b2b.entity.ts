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
 * TB_B2B_CONTRACT — B2B 계약 (도메인 J)
 * DB 설계 v3.4 §4.31
 */
@Entity('tb_b2b_contract')
export class B2bContract {
    @PrimaryGeneratedColumn('uuid', { name: 'contract_id' })
    contractId: string;

    @Column({ name: 'org_id', type: 'uuid' })
    orgId: string;

    @Column({ name: 'contract_name', type: 'varchar', length: 200 })
    contractName: string;

    @Column({ name: 'start_date', type: 'date' })
    startDate: Date;

    @Column({ name: 'end_date', type: 'date' })
    endDate: Date;

    @Column({ name: 'max_members', type: 'int', default: 100 })
    maxMembers: number;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'active' })
    status: string; // 'pending' | 'active' | 'expired' | 'terminated'

    /** v3.4: privacy_level 강제 설정 */
    @Column({ name: 'forced_privacy_level', type: 'varchar', length: 30, nullable: true })
    forcedPrivacyLevel: string | null; // 'safety_first' | 'standard'

    @Column({ name: 'forced_sharing_mode', type: 'varchar', length: 20, nullable: true })
    forcedSharingMode: string | null; // 'forced' | 'voluntary'

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
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
