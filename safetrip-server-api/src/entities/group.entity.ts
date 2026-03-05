import {
    Entity, PrimaryGeneratedColumn, Column, CreateDateColumn,
} from 'typeorm';

/**
 * TB_GROUP -- 그룹 (도메인 B)
 * DB 설계 v3.5.1 $4.3
 */
@Entity('tb_group')
export class Group {
    @PrimaryGeneratedColumn('uuid', { name: 'group_id' })
    groupId: string;

    @Column({ name: 'group_name', type: 'varchar', length: 200 })
    groupName: string;

    @Column({ name: 'group_description', type: 'text', nullable: true })
    groupDescription: string | null;

    @Column({ name: 'group_type', type: 'varchar', length: 20, default: 'travel' })
    groupType: string; // 'travel' | 'b2b_school' | 'b2b_corporate'

    @Column({ name: 'owner_user_id', type: 'varchar', length: 128, nullable: true })
    ownerUserId: string | null;

    @Column({ name: 'invite_code', type: 'varchar', length: 8, unique: true, nullable: true })
    inviteCode: string | null;

    @Column({ name: 'invite_link', type: 'text', nullable: true })
    inviteLink: string | null;

    @Column({ name: 'current_member_count', type: 'int', default: 0 })
    currentMemberCount: number;

    @Column({ name: 'max_members', type: 'int', default: 50 })
    maxMembers: number;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'active' })
    status: string; // 'active' | 'inactive'

    @Column({ name: 'expires_at', type: 'timestamptz', nullable: true })
    expiresAt: Date | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;

    @Column({ name: 'deleted_at', type: 'timestamptz', nullable: true })
    deletedAt: Date | null;

    // -- Backward-compat columns (not in SSOT but used by existing code) --

    @Column({ name: 'created_by', type: 'varchar', length: 128, nullable: true, select: false })
    createdBy: string | null;

    @Column({ name: 'is_active', type: 'boolean', default: true })
    isActive: boolean;
}
