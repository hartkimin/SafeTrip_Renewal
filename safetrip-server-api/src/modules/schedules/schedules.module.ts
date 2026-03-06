import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SchedulesController } from './schedules.controller';
import { SchedulesService } from './schedules.service';
import { AiSuggestService } from './ai-suggest.service';
import { TravelSchedule } from '../../entities/travel-schedule.entity';
import { ScheduleHistory } from '../../entities/schedule-history.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Trip } from '../../entities/trip.entity';

@Module({
    imports: [
        TypeOrmModule.forFeature([
            TravelSchedule,
            ScheduleHistory,
            GroupMember,
            Trip,
        ]),
    ],
    controllers: [SchedulesController],
    providers: [SchedulesService, AiSuggestService],
    exports: [SchedulesService],
})
export class SchedulesModule {}
