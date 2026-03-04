import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, UpdateDateColumn, Index } from 'typeorm';

/**
 * TB_AI_USAGE — AI 기능 사용 기록 및 제한 관리
 */
@Entity('tb_ai_usage')
@Index('idx_ai_usage_user_date', ['userId', 'usageDate'])
export class AiUsage {
    @PrimaryGeneratedColumn('uuid', { name: 'usage_id' })
    usageId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    /** 사용 날짜 (YYYY-MM-DD) — 일일 제한 체크용 */
    @Column({ name: 'usage_date', type: 'date' })
    usageDate: Date;

    /** 기능 유형: 'recommendation' | 'optimization' | 'chat' | 'briefing' | 'intelligence' */
    @Column({ name: 'feature_type', type: 'varchar', length: 30 })
    featureType: string;

    /** 사용 횟수 */
    @Column({ name: 'use_count', type: 'int', default: 0 })
    useCount: number;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })
    updatedAt: Date;
}
