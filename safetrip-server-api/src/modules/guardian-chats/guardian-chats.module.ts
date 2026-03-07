import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GuardianMessage } from '../../entities/guardian-message.entity';
import { GuardianLink } from '../../entities/guardian.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { GuardianChatsController } from './guardian-chats.controller';
import { GuardianChatsService } from './guardian-chats.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
    imports: [
        TypeOrmModule.forFeature([GuardianMessage, GuardianLink, GroupMember]),
        NotificationsModule,
    ],
    controllers: [GuardianChatsController],
    providers: [GuardianChatsService],
    exports: [GuardianChatsService],
})
export class GuardianChatsModule {}
