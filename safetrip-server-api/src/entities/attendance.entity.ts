import {
    Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Unique,
} from 'typeorm';

/**
 * TB_ATTENDANCE_CHECK -- 출석 체크 (도메인 B)
 * DB 설계 v3.5.1 $4.8a
 */
@Entity('tb_attendance_check')
export class AttendanceCheck {
    @PrimaryGeneratedColumn('uuid', { name: 'check_id' })
    checkId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'group_id', type: 'uuid' })
    groupId: string;

    @Column({ name: 'initiated_by', type: 'varchar', length: 128 })
    initiatedBy: string;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'ongoing' })
    status: string; // 'ongoing' | 'completed' | 'cancelled'

    @Column({ name: 'deadline_at', type: 'timestamptz' })
    deadlineAt: Date;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;

    @Column({ name: 'completed_at', type: 'timestamptz', nullable: true })
    completedAt: Date | null;
}

/**
 * TB_ATTENDANCE_RESPONSE -- 출석 응답 (도메인 B)
 * DB 설계 v3.5.1 $4.8b
 */
@Entity('tb_attendance_response')
@Unique(['checkId', 'userId'])
export class AttendanceResponse {
    @PrimaryGeneratedColumn('uuid', { name: 'response_id' })
    responseId: string;

    @Column({ name: 'check_id', type: 'uuid' })
    checkId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'response_type', type: 'varchar', length: 20, default: 'unknown' })
    responseType: string; // 'present' | 'absent' | 'unknown'

    @Column({ name: 'responded_at', type: 'timestamptz', nullable: true })
    respondedAt: Date | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}
