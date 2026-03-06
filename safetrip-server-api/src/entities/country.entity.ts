import {
    Entity, PrimaryGeneratedColumn, Column, CreateDateColumn,
} from 'typeorm';

/**
 * TB_COUNTRY -- 국가 목록 (도메인 B)
 * DB 설계 v3.5.1 $4.8
 */
@Entity('tb_country')
export class Country {
    @PrimaryGeneratedColumn('uuid', { name: 'country_id' })
    countryId: string;

    @Column({ name: 'country_code', type: 'varchar', length: 5, unique: true })
    countryCode: string; // ISO 3166-1 alpha-2

    @Column({ name: 'country_name_ko', type: 'varchar', length: 100 })
    countryNameKo: string;

    @Column({ name: 'country_name_en', type: 'varchar', length: 100 })
    countryNameEn: string;

    @Column({ name: 'country_flag_emoji', type: 'varchar', length: 10, nullable: true })
    countryFlagEmoji: string | null;

    @Column({ name: 'phone_code', type: 'varchar', length: 10, nullable: true })
    phoneCode: string | null;

    @Column({ name: 'region', type: 'varchar', length: 50, nullable: true })
    region: string | null;

    @Column({ name: 'mofa_travel_alert', type: 'varchar', length: 20, default: 'none' })
    mofaTravelAlert: string; // 'none' | 'watch' | 'warning' | 'danger' | 'ban'

    @Column({ name: 'mofa_alert_updated_at', type: 'timestamptz', nullable: true })
    mofaAlertUpdatedAt: Date | null;

    @Column({ name: 'is_popular', type: 'boolean', default: false })
    isPopular: boolean;

    @Column({ name: 'sort_order', type: 'int', default: 0 })
    sortOrder: number;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;
}
