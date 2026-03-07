import {
    Entity, PrimaryGeneratedColumn, Column, CreateDateColumn,
} from 'typeorm';

/**
 * TB_INVITE_CODE -- 역할별 초대코드 (도메인 B)
 * DB 설계 v3.6 §4.6, 초대코드 원칙 §13.1
 */
@Entity('tb_invite_code')
export class InviteCode {
    @PrimaryGeneratedColumn('uuid', { name: 'invite_code_id' })
    inviteCodeId: string;

    @Column({ name: 'group_id', type: 'uuid', nullable: true })
    groupId: string;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'code', type: 'varchar', length: 7, unique: true })
    code: string;

    @Column({ name: 'target_role', type: 'varchar', length: 30 })
    targetRole: string; // 'crew_chief' | 'crew' | 'guardian'

    @Column({ name: 'max_uses', type: 'int', default: 1 })
    maxUses: number;

    @Column({ name: 'current_uses', type: 'int', default: 0 })
    currentUses: number;

    @Column({ name: 'expires_at', type: 'timestamptz' })
    expiresAt: Date;

    @Column({ name: 'created_by', type: 'varchar', length: 128, nullable: true })
    createdBy: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'is_active', type: 'boolean', default: true })
    isActive: boolean;

    @Column({ name: 'b2b_batch_id', type: 'uuid', nullable: true })
    b2bBatchId: string | null;

    @Column({ name: 'model_type', type: 'varchar', length: 20, default: 'direct' })
    modelType: string; // 'direct' | 'system'
}
