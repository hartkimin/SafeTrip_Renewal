import {
    Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index,
} from 'typeorm';

/**
 * TB_GROUP_MEMBER -- 그룹 멤버 (도메인 B)
 * DB 설계 v3.5.1 $4.5
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

    @Column({ name: 'member_role', type: 'varchar', length: 30, default: 'crew' })
    memberRole: string; // 'captain' | 'crew_chief' | 'crew' | 'guardian'

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'is_admin', type: 'boolean', default: false })
    isAdmin: boolean;

    @Column({ name: 'is_guardian', type: 'boolean', default: false })
    isGuardian: boolean;

    @Column({ name: 'can_edit_schedule', type: 'boolean', default: false })
    canEditSchedule: boolean;

    @Column({ name: 'can_edit_geofence', type: 'boolean', default: false })
    canEditGeofence: boolean;

    @Column({ name: 'can_view_all_locations', type: 'boolean', default: true })
    canViewAllLocations: boolean;

    @Column({ name: 'can_attendance_check', type: 'boolean', default: true })
    canAttendanceCheck: boolean;

    @Column({ name: 'traveler_user_id', type: 'varchar', length: 128, nullable: true })
    travelerUserId: string | null;

    @Column({ name: 'location_sharing_enabled', type: 'boolean', default: true })
    locationSharingEnabled: boolean;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'active' })
    status: string; // 'active' | 'left' | 'removed'

    @CreateDateColumn({ name: 'joined_at', type: 'timestamptz' })
    createdAt: Date;

    /** SSOT alias: joined_at column, exposed as joinedAt for new code */
    get joinedAt(): Date { return this.createdAt; }

    @Column({ name: 'left_at', type: 'timestamptz', nullable: true })
    leftAt: Date | null;

    // -- Backward-compat columns (not in SSOT but used by existing code) --

    @Column({ name: 'can_manage_members', type: 'boolean', default: false, select: false })
    canManageMembers: boolean;

    @Column({ name: 'can_send_notifications', type: 'boolean', default: false, select: false })
    canSendNotifications: boolean;

    @Column({ name: 'can_view_location', type: 'boolean', default: true, select: false })
    canViewLocation: boolean;

    @Column({ name: 'can_manage_geofences', type: 'boolean', default: false, select: false })
    canManageGeofences: boolean;
}
