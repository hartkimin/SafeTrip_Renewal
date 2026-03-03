import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TripsController } from './trips.controller';
import { TripsService } from './trips.service';
import { Trip, Group, GroupMember, ChatRoom, GuardianLink, Schedule, TravelSchedule, InviteCode } from '../../entities';

@Module({
    imports: [TypeOrmModule.forFeature([Trip, Group, GroupMember, ChatRoom, GuardianLink, Schedule, TravelSchedule, InviteCode])],
    controllers: [TripsController],
    providers: [TripsService],
    exports: [TripsService],
})
export class TripsModule { }
