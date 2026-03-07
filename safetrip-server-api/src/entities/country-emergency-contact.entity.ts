import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

/**
 * TB_COUNTRY_EMERGENCY_CONTACT — 국가별 긴급연락처 (안전가이드)
 * DOC-T3-SFG-021 §7.2
 *
 * NOTE: 기존 TB_EMERGENCY_CONTACT (도메인 A, emergency.entity.ts)는 사용자 개인 비상연락처.
 *       이 테이블은 국가별 긴급 서비스 번호 (경찰·소방·영사관 등).
 */
@Entity('tb_country_emergency_contact')
@Index('idx_country_emergency_contact_country', ['countryCode'])
export class CountryEmergencyContact {
    @PrimaryGeneratedColumn('increment', { name: 'id', type: 'bigint' })
    id: string;

    @Column({ name: 'country_code', type: 'varchar', length: 3 })
    countryCode: string;

    /** 'police' | 'fire' | 'ambulance' | 'embassy' | 'consulate_call_center' */
    @Column({ name: 'contact_type', type: 'varchar', length: 20 })
    contactType: string;

    @Column({ name: 'phone_number', type: 'varchar', length: 30 })
    phoneNumber: string;

    @Column({ name: 'description_ko', type: 'varchar', length: 100, nullable: true })
    descriptionKo: string | null;

    @Column({ name: 'is_24h', type: 'boolean', default: true })
    is24h: boolean;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', default: () => 'now()' })
    updatedAt: Date;
}
