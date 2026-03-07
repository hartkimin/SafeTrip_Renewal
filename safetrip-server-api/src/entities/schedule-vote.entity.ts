import {
    Entity,
    PrimaryGeneratedColumn,
    Column,
    Index,
} from 'typeorm';

/**
 * TB_SCHEDULE_VOTE -- 일정 투표 (도메인 D)
 * P3 투표 시스템: 그룹 일정 결정을 위한 투표
 */
@Entity('tb_schedule_vote')
@Index('idx_schedule_vote_trip', ['tripId'])
export class ScheduleVote {
    @PrimaryGeneratedColumn('uuid')
    id: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'title', type: 'varchar', length: 200 })
    title: string;

    @Column({ name: 'created_by', type: 'varchar', length: 128 })
    createdBy: string;

    @Column({ name: 'status', type: 'varchar', length: 20, default: 'open' })
    status: string; // 'open' | 'closed'

    @Column({ name: 'deadline', type: 'timestamptz', nullable: true })
    deadline: Date | null;

    @Column({ name: 'created_at', type: 'timestamptz', default: () => 'NOW()' })
    createdAt: Date;
}
