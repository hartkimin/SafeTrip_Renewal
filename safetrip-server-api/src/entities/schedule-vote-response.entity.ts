import {
    Entity,
    PrimaryGeneratedColumn,
    Column,
    Unique,
} from 'typeorm';

/**
 * TB_SCHEDULE_VOTE_RESPONSE -- 투표 응답 (도메인 D)
 * P3 투표 시스템: 사용자의 투표 응답 (투표당 1회)
 */
@Entity('tb_schedule_vote_response')
@Unique('uq_vote_response', ['voteId', 'userId'])
export class ScheduleVoteResponse {
    @PrimaryGeneratedColumn('uuid')
    id: string;

    @Column({ name: 'vote_id', type: 'uuid' })
    voteId: string;

    @Column({ name: 'option_id', type: 'uuid' })
    optionId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'created_at', type: 'timestamptz', default: () => 'NOW()' })
    createdAt: Date;
}
