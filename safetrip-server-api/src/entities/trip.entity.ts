import {
    Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Check,
} from 'typeorm';

/**
 * TB_TRIP -- 여행 (도메인 B)
 * DB 설계 v3.5.1 $4.4
 */
@Entity('tb_trip')
@Check(`"end_date" IS NULL OR "start_date" IS NULL OR "end_date" - "start_date" <= 15`)
export class Trip {
    @PrimaryGeneratedColumn('uuid', { name: 'trip_id' })
    tripId: string;

    @Column({ name: 'group_id', type: 'uuid' })
    groupId: string;

    @Column({ name: 'trip_name', type: 'varchar', length: 200, nullable: true })
    tripName: string | null;

    @Column({ name: 'destination', type: 'varchar', length: 200, nullable: true })
    destination: string | null;

    @Column({ name: 'destination_city', type: 'varchar', length: 200, nullable: true })
    destinationCity: string | null;

    @Column({ name: 'destination_country_code', type: 'varchar', length: 10, nullable: true })
    destinationCountryCode: string | null;

    @Column({ name: 'country_code', type: 'varchar', length: 10, nullable: true })
    countryCode: string | null;

    @Column({ name: 'country_name', type: 'varchar', length: 100, nullable: true })
    countryName: string | null;

    @Column({ name: 'trip_type', type: 'varchar', length: 20, nullable: true })
    tripType: string | null; // 'group' | 'solo'

    @Column({ name: 'start_date', type: 'date' })
    startDate: Date;

    @Column({ name: 'end_date', type: 'date' })
    endDate: Date;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'planning' })
    status: string; // 'planning' | 'active' | 'completed'

    @Column({ name: 'privacy_level', type: 'varchar', length: 20, default: 'standard' })
    privacyLevel: string; // 'safety_first' | 'standard' | 'privacy_first'

    @Column({ name: 'sharing_mode', type: 'varchar', length: 20, default: 'voluntary' })
    sharingMode: string; // 'forced' | 'voluntary'

    @Column({ name: 'schedule_type', type: 'varchar', length: 20, default: 'always' })
    scheduleType: string; // 'always' | 'time_based' | 'schedule_linked'

    @Column({ name: 'schedule_buffer_minutes', type: 'int', default: 15 })
    scheduleBufferMinutes: number;

    /** B2B 계약 연결 */
    @Column({ name: 'b2b_contract_id', type: 'uuid', nullable: true })
    b2bContractId: string | null;

    /** 미성년자 포함 여부 (safety_first 강제) */
    @Column({ name: 'has_minor_members', type: 'boolean', default: false })
    hasMinorMembers: boolean;

    /** v3.4: 여행 재활성화 추적 */
    @Column({ name: 'reactivated_at', type: 'timestamptz', nullable: true })
    reactivatedAt: Date | null;

    @Column({ name: 'reactivation_count', type: 'int', default: 0 })
    reactivationCount: number;

    @Column({ name: 'created_by', type: 'varchar', length: 128, nullable: true })
    createdBy: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;

    @Column({ name: 'deleted_at', type: 'timestamptz', nullable: true })
    deletedAt: Date | null;
}
