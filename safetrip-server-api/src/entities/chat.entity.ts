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
 * DB 설계 v3.5.1 §4.23
 */
@Entity('tb_chat_message')
@Index('idx_chat_message_room', ['roomId', 'sentAt'])
@Index('idx_chat_message_trip', ['tripId', 'sentAt'])
export class ChatMessage {
    @PrimaryGeneratedColumn('uuid', { name: 'message_id' })
    messageId: string;

    @Column({ name: 'room_id', type: 'uuid', nullable: true })
    roomId: string | null;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'group_id', type: 'uuid', nullable: true })
    groupId: string | null;

    @Column({ name: 'sender_id', type: 'varchar', length: 128, nullable: true })
    senderId: string | null;

    @Column({ name: 'message_type', type: 'varchar', length: 20, default: 'text' })
    messageType: string;
    // 'text' | 'image' | 'video' | 'file' | 'location' | 'poll' | 'system'

    @Column({ name: 'content', type: 'text', nullable: true })
    content: string | null;

    @Column({ name: 'media_urls', type: 'jsonb', nullable: true })
    mediaUrls: any; // [{url, type, size, thumbnail}]

    @Column({ name: 'location_data', type: 'jsonb', nullable: true })
    locationData: any; // {lat, lng, address, place_name}

    @Column({ name: 'reply_to_id', type: 'uuid', nullable: true })
    replyToId: string | null;

    @Column({ name: 'system_event_type', type: 'varchar', length: 50, nullable: true })
    systemEventType: string | null;

    @Column({ name: 'system_event_level', type: 'varchar', length: 20, nullable: true })
    systemEventLevel: string | null;
    // 'INFO' | 'SCHEDULE' | 'WARNING' | 'CRITICAL' | 'CELEBRATION'

    @Column({ name: 'is_pinned', type: 'boolean', default: false })
    isPinned: boolean;

    @Column({ name: 'pinned_by', type: 'varchar', length: 128, nullable: true })
    pinnedBy: string | null;

    @Column({ name: 'is_deleted', type: 'boolean', default: false })
    isDeleted: boolean;

    @Column({ name: 'deleted_by', type: 'varchar', length: 128, nullable: true })
    deletedBy: string | null;

    @Column({ name: 'metadata', type: 'jsonb', nullable: true })
    metadata: any;

    @CreateDateColumn({ name: 'sent_at', type: 'timestamptz' })
    sentAt: Date;

    @Column({ name: 'updated_at', type: 'timestamptz', nullable: true })
    updatedAt: Date | null;
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

    @Column({ name: 'room_id', type: 'uuid', nullable: true })
    roomId: string | null;

    @Column({ name: 'trip_id', type: 'uuid', nullable: true })
    tripId: string | null;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'last_read_message_id', type: 'uuid', nullable: true })
    lastReadMessageId: string | null;

    @Column({ name: 'last_read_at', type: 'timestamptz', nullable: true })
    lastReadAt: Date | null;
}

/**
 * TB_CHAT_POLL — 투표 (도메인 G)
 * DB 설계 v3.5.1 §4.24
 */
@Entity('tb_chat_poll')
export class ChatPoll {
    @PrimaryGeneratedColumn('uuid', { name: 'poll_id' })
    pollId: string;

    @Column({ name: 'message_id', type: 'uuid' })
    messageId: string;

    @Column({ name: 'trip_id', type: 'uuid' })
    tripId: string;

    @Column({ name: 'creator_id', type: 'varchar', length: 128 })
    creatorId: string;

    @Column({ name: 'title', type: 'varchar', length: 200 })
    title: string;

    @Column({ name: 'options', type: 'jsonb' })
    options: any; // [{id, text, color}]

    @Column({ name: 'allow_multiple', type: 'boolean', default: false })
    allowMultiple: boolean;

    @Column({ name: 'is_anonymous', type: 'boolean', default: false })
    isAnonymous: boolean;

    @Column({ name: 'closes_at', type: 'timestamptz', nullable: true })
    closesAt: Date | null;

    @Column({ name: 'is_closed', type: 'boolean', default: false })
    isClosed: boolean;

    @Column({ name: 'closed_by', type: 'varchar', length: 128, nullable: true })
    closedBy: string | null;

    @CreateDateColumn({ name: 'created_at', type: 'timestamptz' })
    createdAt: Date;
}

/**
 * TB_CHAT_POLL_VOTE — 투표 응답 (도메인 G)
 * DB 설계 v3.5.1 §4.25
 */
@Entity('tb_chat_poll_vote')
@Index('idx_chat_poll_vote_unique', ['pollId', 'userId'], { unique: true })
export class ChatPollVote {
    @PrimaryGeneratedColumn('uuid', { name: 'vote_id' })
    voteId: string;

    @Column({ name: 'poll_id', type: 'uuid' })
    pollId: string;

    @Column({ name: 'user_id', type: 'varchar', length: 128 })
    userId: string;

    @Column({ name: 'selected_options', type: 'jsonb' })
    selectedOptions: number[]; // integer array

    @CreateDateColumn({ name: 'voted_at', type: 'timestamptz' })
    votedAt: Date;
}
