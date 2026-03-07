import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

/**
 * TB_SAFETY_GUIDE_CACHE — MOFA API 응답 캐시 (안전가이드)
 * DOC-T3-SFG-021 §7.1
 */
@Entity('tb_safety_guide_cache')
@Index('idx_safety_cache_country', ['countryCode'])
@Index('idx_safety_cache_expires', ['expiresAt'])
export class SafetyGuideCache {
    @PrimaryGeneratedColumn('increment', { name: 'id', type: 'bigint' })
    id: string;

    @Column({ name: 'country_code', type: 'varchar', length: 3 })
    countryCode: string;

    /** 'travel_alert' | 'safety_notice' | 'country_info' | 'entry_info' | 'embassy' | 'incident_report' */
    @Column({ name: 'data_type', type: 'varchar', length: 30 })
    dataType: string;

    @Column({ name: 'content', type: 'jsonb' })
    content: any;

    @Column({ name: 'fetched_at', type: 'timestamptz' })
    fetchedAt: Date;

    @Column({ name: 'expires_at', type: 'timestamptz' })
    expiresAt: Date;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', default: () => 'now()' })
    updatedAt: Date;
}
