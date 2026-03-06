import {
    Entity,
    PrimaryGeneratedColumn,
    Column,
} from 'typeorm';

/**
 * TB_SCHEDULE_VOTE_OPTION -- 투표 선택지 (도메인 D)
 * P3 투표 시스템: 각 투표의 선택 옵션
 */
@Entity('tb_schedule_vote_option')
export class ScheduleVoteOption {
    @PrimaryGeneratedColumn('uuid')
    id: string;

    @Column({ name: 'vote_id', type: 'uuid' })
    voteId: string;

    @Column({ name: 'label', type: 'varchar', length: 200 })
    label: string;

    @Column({ name: 'schedule_data', type: 'jsonb', nullable: true })
    scheduleData: any;
}
