import {
    Entity, PrimaryGeneratedColumn, Column, CreateDateColumn,
} from 'typeorm';

/**
 * TB_GROUP — 그룹 (도메인 B)
 * DB 설계 v3.4 §4.3
 */
@Entity('tb_group')
export class Group {
    @PrimaryGeneratedColumn('uuid', { name: 'group_id' })
    groupId: string;

    @Column({ name: 'group_name', type: 'varchar', length: 100 })
    groupName: string;

    @Column({ name: 'group_type', type: 'varchar', length: 20, default: 'personal' })
    groupType: string; // 'personal' | 'b2b_school' | 'b2b_corporate'

    @Column({ name: 'created_by', type: 'varchar', length: 128 })
    createdBy: string;

    @Column({ name: 'is_active', type: 'boolean', default: true })
    isActive: boolean;

    @Column({ name: 'max_members', type: 'int', default: 50 })
    maxMembers: number;

    @Column({ name: 'current_member_count', type: 'int', default: 1 })
    currentMemberCount: number;

    @Column({ name: 'invite_code', type: 'varchar', length: 20, nullable: true })
    inviteCode: string;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}
