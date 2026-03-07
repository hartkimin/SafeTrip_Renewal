import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

/**
 * TB_CHAT_REACTION -- 채팅 리액션 (도메인 G)
 * Phase 3: DOC-T3-CHT-020 §9
 */
@Entity('tb_chat_reaction')
@Index('idx_chat_reaction_unique', ['messageId', 'userId', 'emoji'], { unique: true })
export class ChatReaction {
    @PrimaryGeneratedColumn('increment', { name: 'reaction_id', type: 'bigint' })
    reactionId: string;

    @Column({ name: 'message_id', type: 'bigint' })
    messageId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'emoji', type: 'varchar', length: 10 })
    emoji: string;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}
