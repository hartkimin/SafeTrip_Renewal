import {
    Entity,
    PrimaryGeneratedColumn,
    Column,
    Unique,
    Index,
} from 'typeorm';

/**
 * TB_SCHEDULE_REACTION -- 일정 리액션 (도메인 D)
 * P3 소셜 기능: 일정에 대한 이모지 리액션
 */
@Entity('tb_schedule_reaction')
@Unique('uq_schedule_reaction', ['scheduleId', 'userId', 'emoji'])
@Index('idx_schedule_reaction_schedule', ['scheduleId'])
export class ScheduleReaction {
    @PrimaryGeneratedColumn('uuid')
    id: string;

    @Column({ name: 'schedule_id', type: 'uuid' })
    scheduleId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'emoji', type: 'varchar', length: 10 })
    emoji: string;

    @Column({ name: 'created_at', type: 'timestamptz', default: () => 'NOW()' })
    createdAt: Date;
}
