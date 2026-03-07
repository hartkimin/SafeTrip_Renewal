import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

/**
 * TB_GUARDIAN_MESSAGE -- 가디언 1:1 채팅 메시지 (Phase 2)
 * Guardian-member direct messaging channel
 */
@Entity('tb_guardian_message')
@Index('idx_guardian_msg_link', ['linkId', 'sentAt'])
export class GuardianMessage {
    @PrimaryGeneratedColumn('increment', { name: 'message_id', type: 'bigint' })
    messageId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'link_id', type: 'uuid' })
    linkId: string;

    @Column({ name: 'sender_type', type: 'varchar', length: 20 })
    senderType: string; // 'member' | 'guardian'

    @Column({ name: 'sender_id', type: 'varchar', length: 128 })
    senderId: string;

    @Column({ name: 'message_type', type: 'varchar', length: 20, default: 'text' })
    messageType: string; // 'text' | 'location_card' | 'system'

    @Column({ name: 'content', type: 'text', nullable: true })
    content: string | null;

    @Column({ name: 'card_data', type: 'jsonb', nullable: true })
    cardData: any;

    @Column({ name: 'is_read', type: 'boolean', default: false })
    isRead: boolean;

    @CreateDateColumn({ name: 'sent_at', type: 'timestamptz' })
    sentAt: Date;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}
