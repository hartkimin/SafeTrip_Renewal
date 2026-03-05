import { Entity, PrimaryColumn, Column, CreateDateColumn } from 'typeorm';

/**
 * TB_COUNTRY_SAFETY — 국가 안전 정보 (도메인 J)
 * DB 설계 v3.4 §4.39
 */
@Entity('tb_country_safety')
export class CountrySafety {
    @PrimaryColumn({ name: 'country_code', type: 'varchar', length: 3 })
    countryCode: string;

    @Column({ name: 'country_name_ko', type: 'varchar', length: 100 })
    countryNameKo: string;

    @Column({ name: 'country_name_en', type: 'varchar', length: 100, nullable: true })
    countryNameEn: string;

    @Column({ name: 'travel_alert_level', type: 'int', nullable: true })
    travelAlertLevel: number;

    @Column({ name: 'travel_alert_description', type: 'text', nullable: true })
    travelAlertDescription: string;

    @Column({ name: 'emergency_number', type: 'varchar', length: 20, nullable: true })
    emergencyNumber: string;

    @Column({ name: 'embassy_phone', type: 'varchar', length: 50, nullable: true })
    embassyPhone: string;

    @Column({ name: 'embassy_address', type: 'text', nullable: true })
    embassyAddress: string;

    @Column({ name: 'mofa_data', type: 'jsonb', nullable: true })
    mofaData: any;

    @Column({ name: 'last_synced_at', type: 'timestamptz', nullable: true })
    lastSyncedAt: Date;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date;
}
