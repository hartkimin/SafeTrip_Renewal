import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ChatsController } from './chats.controller';
import { ChatsService } from './chats.service';
import { ChatsGateway } from './chats.gateway';
import { ChatRoom, ChatMessage, ChatReadStatus } from '../../entities/chat.entity';

@Module({
    imports: [TypeOrmModule.forFeature([ChatRoom, ChatMessage, ChatReadStatus])],
    controllers: [ChatsController],
    providers: [ChatsService, ChatsGateway],
    exports: [ChatsService, ChatsGateway],
})
export class ChatsModule { }
