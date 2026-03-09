import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { EmergenciesController } from './emergencies.controller';
import { EmergenciesService } from './emergencies.service';
import { Emergency, EmergencyContact, SosEvent, NoResponseEvent } from '../../entities/emergency.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Guardian, GuardianLink } from '../../entities/guardian.entity';
import { User } from '../../entities/user.entity';
import { NotificationsModule } from '../notifications/notifications.module';
import { ChatsModule } from '../chats/chats.module';

@Module({
    imports: [
        TypeOrmModule.forFeature([
            Emergency, EmergencyContact, SosEvent, NoResponseEvent,
            GroupMember, Guardian, GuardianLink, User
        ]),
        NotificationsModule,
        ChatsModule,
    ],
    controllers: [EmergenciesController],
    providers: [EmergenciesService],
    exports: [EmergenciesService],
})
export class EmergenciesModule { }
