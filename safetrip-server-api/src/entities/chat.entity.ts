import { Entity, PrimaryGeneratedColumn, Column, CreateDateColumn, Index } from 'typeorm';

/**
 * TB_CHAT_ROOM — 채팅방 (도메인 G)
 * DB 설계 v3.4 §4.23
 */
@Entity('tb_chat_room')
export class ChatRoom {
    @PrimaryGeneratedColumn('uuid', { name: 'room_id' })
    roomId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'room_type', type: 'varchar', length: 20, default: 'group' })
    roomType: string; // 'group' | 'guardian' | 'dm'

    @Column({ name: 'room_name', type: 'varchar', length: 100, nullable: true })
    roomName: string | null;

    @Column({ name: 'is_active', type: 'boolean', default: true })
    isActive: boolean;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}

/**
 * TB_CHAT_MESSAGE — 채팅 메시지 (도메인 G)
 * DB 설계 v3.4 §4.24
 */
@Entity('tb_chat_message')
@Index('idx_chat_message_room', ['roomId', 'sentAt'])
export class ChatMessage {
    @PrimaryGeneratedColumn('uuid', { name: 'message_id' })
    messageId: string;

    @Column({ name: 'room_id', type: 'uuid' })
    roomId: string;

    @Column({ name: 'sender_id', type: 'varchar', length: 128 })
    senderId: string;

    @Column({ name: 'message_type', type: 'varchar', length: 20, default: 'text' })
    messageType: string; // 'text' | 'image' | 'location' | 'system' | 'sos_alert'

    @Column({ name: 'content', type: 'text', nullable: true })
    content: string | null;

    @Column({ name: 'metadata', type: 'jsonb', nullable: true })
    metadata: any;

    @Column({ name: 'is_deleted', type: 'boolean', default: false })
    isDeleted: boolean;

    @CreateDateColumn({ name: 'sent_at', type: 'timestamptz' })
    sentAt: Date;
}

/**
 * TB_CHAT_READ_STATUS — 읽음 상태 (도메인 G)
 * DB 설계 v3.4 §4.25
 */
@Entity('tb_chat_read_status')
@Index('idx_chat_read_room_user', ['roomId', 'userId'], { unique: true })
export class ChatReadStatus {
    @PrimaryGeneratedColumn('uuid', { name: 'read_id' })
    readId: string;

    @Column({ name: 'room_id', type: 'uuid' })
    roomId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'last_read_message_id', type: 'uuid', nullable: true })
    lastReadMessageId: string | null;

    @Column({ name: 'last_read_at', type: 'timestamptz', nullable: true })
    lastReadAt: Date | null;
}
