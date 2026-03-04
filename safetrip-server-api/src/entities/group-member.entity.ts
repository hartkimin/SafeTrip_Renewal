import {
    Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index,
} from 'typeorm';

/**
 * TB_GROUP_MEMBER — 그룹 멤버 (도메인 B)
 * DB 설계 v3.4 §4.5
 * v3.4: captain 유일성 부분 인덱스 (idx_group_member_captain)
 */
@Entity('tb_group_member')
@Index('idx_group_member_captain', ['tripId'], {
    unique: true,
    where: `"member_role" = 'captain' AND "status" = 'active'`,
})
@Index('idx_group_member_trip', ['tripId'])
export class GroupMember {
    @PrimaryGeneratedColumn('uuid', { name: 'member_id' })
    memberId: string;

    @Column({ name: 'group_id', type: 'uuid' })
    groupId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string; // NOT NULL 확정 (v3.0)

    @Column({ name: 'member_role', type: 'varchar', length: 20, default: 'crew' })
    memberRole: string; // 'captain' | 'crew_chief' | 'crew' | 'guardian'

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'active' })
    status: string; // 'active' | 'left' | 'removed'

    @Column({ name: 'is_admin', type: 'boolean', default: false })
    isAdmin: boolean;

    @Column({ name: 'location_sharing_enabled', type: 'boolean', default: true })
    locationSharingEnabled: boolean;

    @Column({ name: 'can_edit_schedule', type: 'boolean', default: false })
    canEditSchedule: boolean;

    @Column({ name: 'can_manage_members', type: 'boolean', default: false })
    canManageMembers: boolean;

    @Column({ name: 'can_send_notifications', type: 'boolean', default: false })
    canSendNotifications: boolean;

    @Column({ name: 'can_view_location', type: 'boolean', default: true })
    canViewLocation: boolean;

    @Column({ name: 'can_manage_geofences', type: 'boolean', default: false })
    canManageGeofences: boolean;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'left_at', type: 'timestamptz', nullable: true })
    leftAt: Date | null;
}
