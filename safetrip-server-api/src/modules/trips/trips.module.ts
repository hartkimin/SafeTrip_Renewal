import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TripsController } from './trips.controller';
import { TripsService } from './trips.service';
import { Trip, User, Group, GroupMember, ChatRoom, Guardian, GuardianLink, Schedule, TravelSchedule, InviteCode, Country } from '../../entities';
import { PaymentsModule } from '../payments/payments.module';
import { B2bModule } from '../b2b/b2b.module';
import { InviteCodesModule } from '../invite-codes/invite-codes.module';

@Module({
    imports: [
        TypeOrmModule.forFeature([Trip, User, Group, GroupMember, ChatRoom, Guardian, GuardianLink, Schedule, TravelSchedule, InviteCode, Country]),
        PaymentsModule,
        B2bModule,
        InviteCodesModule,
    ],
    controllers: [TripsController],
    providers: [TripsService],
    exports: [TripsService],
})
export class TripsModule { }
