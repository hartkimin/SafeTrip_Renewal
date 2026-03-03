import {
    Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, JoinColumn, ManyToOne,
} from 'typeorm';
import { Group } from './group.entity';
import { User } from './user.entity';

@Entity('tb_invite_code')
export class InviteCode {
    @PrimaryGeneratedColumn('uuid', { name: 'invite_code_id' })
    inviteCodeId: string;

    @Column({ name: 'group_id', type: 'uuid' })
    groupId: string;

    @ManyToOne(() => Group)
    @JoinColumn({ name: 'group_id' })
    group: Group;

    @Column({ name: 'code', type: 'varchar', length: 20, unique: true })
    code: string;

    @Column({ name: 'target_role', type: 'varchar', length: 20 })
    targetRole: string; // 'crew_chief', 'crew', 'guardian'

    @Column({ name: 'max_uses', type: 'int', nullable: true })
    maxUses: number | null;

    @Column({ name: 'used_count', type: 'int', default: 0 })
    usedCount: number;

    @Column({ name: 'expires_at', type: 'timestamptz', nullable: true })
    expiresAt: Date | null;

    @Column({ name: 'is_active', type: 'boolean', default: true })
    isActive: boolean;

    @Column({ name: 'created_by', type: 'uuid' })
    createdBy: string;

    @ManyToOne(() => User)
    @JoinColumn({ name: 'created_by' })
    creator: User;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}
