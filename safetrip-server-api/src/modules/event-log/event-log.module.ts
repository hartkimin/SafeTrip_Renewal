import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { EventLogController } from './event-log.controller';
import { EventLogService } from './event-log.service';
import { EventLog } from '../../entities/event-log.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Geofence } from '../../entities/geofence.entity';
import { User } from '../../entities/user.entity';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
    imports: [
        TypeOrmModule.forFeature([EventLog, GroupMember, Geofence, User]),
        NotificationsModule
    ],
    controllers: [EventLogController],
    providers: [EventLogService],
    exports: [EventLogService],
})
export class EventLogModule { }
