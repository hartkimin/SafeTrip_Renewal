import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SchedulesController } from './schedules.controller';
import { SchedulesService } from './schedules.service';
import { AiSuggestService } from './ai-suggest.service';
import { ScheduleSocialService } from './schedule-social.service';
import { ScheduleVoteController } from './schedule-vote.controller';
import { ScheduleVoteService } from './schedule-vote.service';
import { WeatherService } from './weather.service';
import { ScheduleTemplateService } from './schedule-template.service';
import { ScheduleTemplateController } from './schedule-template.controller';
import { TravelSchedule } from '../../entities/travel-schedule.entity';
import { ScheduleHistory } from '../../entities/schedule-history.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Trip } from '../../entities/trip.entity';
import { ScheduleComment } from '../../entities/schedule-comment.entity';
import { ScheduleReaction } from '../../entities/schedule-reaction.entity';
import { ScheduleVote } from '../../entities/schedule-vote.entity';
import { ScheduleVoteOption } from '../../entities/schedule-vote-option.entity';
import { ScheduleVoteResponse } from '../../entities/schedule-vote-response.entity';
import { ScheduleTemplate } from '../../entities/schedule-template.entity';

@Module({
    imports: [
        TypeOrmModule.forFeature([
            TravelSchedule,
            ScheduleHistory,
            GroupMember,
            Trip,
            ScheduleComment,
            ScheduleReaction,
            ScheduleVote,
            ScheduleVoteOption,
            ScheduleVoteResponse,
            ScheduleTemplate,
        ]),
    ],
    controllers: [
        SchedulesController,
        ScheduleVoteController,
        ScheduleTemplateController,
    ],
    providers: [
        SchedulesService,
        AiSuggestService,
        ScheduleSocialService,
        ScheduleVoteService,
        WeatherService,
        ScheduleTemplateService,
    ],
    exports: [SchedulesService],
})
export class SchedulesModule {}
