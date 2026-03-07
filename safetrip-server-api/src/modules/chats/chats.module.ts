import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ChatsController } from './chats.controller';
import { ChatsService } from './chats.service';
import { ChatsGateway } from './chats.gateway';
import { SystemMessageService } from './system-message.service';
import { PollService } from './poll.service';
import { ChatRoom, ChatMessage, ChatReadStatus, ChatPoll, ChatPollVote } from '../../entities/chat.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { User } from '../../entities/user.entity';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
    imports: [
        TypeOrmModule.forFeature([
            ChatRoom, ChatMessage, ChatReadStatus,
            ChatPoll, ChatPollVote,
            GroupMember, User,
        ]),
        NotificationsModule,
    ],
    controllers: [ChatsController],
    providers: [ChatsService, ChatsGateway, SystemMessageService, PollService],
    exports: [ChatsService, ChatsGateway, SystemMessageService, PollService],
})
export class ChatsModule { }
