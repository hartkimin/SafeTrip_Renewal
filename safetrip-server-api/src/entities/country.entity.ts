import { Entity, Column, PrimaryColumn, CreateDateColumn, UpdateDateColumn, DeleteDateColumn } from 'typeorm';

@Entity('tb_country')
export class Country {
    @PrimaryColumn({ name: 'country_code' })
    countryCode: string;

    @Column({ name: 'country_name_ko', nullable: true })
    countryNameKo: string;

    @Column({ name: 'country_name_en' })
    countryNameEn: string;

    @Column({ name: 'country_name_local', nullable: true })
    countryNameLocal: string;

    @Column({ name: 'flag_emoji', nullable: true })
    flagEmoji: string;

    @Column({ name: 'iso_alpha2', nullable: true })
    isoAlpha2: string;

    @Column({ name: 'is_active', default: true })
    isActive: boolean;

    @CreateDateColumn({ name: 'created_at' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at' })
    updatedAt: Date;

    @DeleteDateColumn({ name: 'deleted_at' })
    deletedAt: Date;
}
