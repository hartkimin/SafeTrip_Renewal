import {
    Entity,
    PrimaryGeneratedColumn,
    Column,
    Index,
} from 'typeorm';

/**
 * TB_SCHEDULE_COMMENT -- 일정 댓글 (도메인 D)
 * P3 소셜 기능: 일정에 대한 댓글
 */
@Entity('tb_schedule_comment')
@Index('idx_schedule_comment_schedule', ['scheduleId'])
export class ScheduleComment {
    @PrimaryGeneratedColumn('uuid')
    id: string;

    @Column({ name: 'schedule_id', type: 'uuid' })
    scheduleId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'content', type: 'text' })
    content: string;

    @Column({ name: 'created_at', type: 'timestamptz', default: () => 'NOW()' })
    createdAt: Date;

    @Column({ name: 'deleted_at', type: 'timestamptz', nullable: true })
    deletedAt: Date | null;
}
