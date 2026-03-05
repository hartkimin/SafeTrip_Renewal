import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ChatsController } from './chats.controller';
import { ChatsService } from './chats.service';
import { ChatsGateway } from './chats.gateway';
import { ChatRoom, ChatMessage, ChatReadStatus } from '../../entities/chat.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { User } from '../../entities/user.entity';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
    imports: [
        TypeOrmModule.forFeature([ChatRoom, ChatMessage, ChatReadStatus, GroupMember, User]),
        NotificationsModule
    ],
    controllers: [ChatsController],
    providers: [ChatsService, ChatsGateway],
    exports: [ChatsService, ChatsGateway],
})
export class ChatsModule { }
