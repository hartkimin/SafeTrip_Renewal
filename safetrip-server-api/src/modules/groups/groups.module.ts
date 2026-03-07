import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GroupsController } from './groups.controller';
import { GroupsService } from './groups.service';
import { Group } from '../../entities/group.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { InviteCode } from '../../entities/invite-code.entity';
import { Trip } from '../../entities/trip.entity';
import { Schedule } from '../../entities/schedule.entity';
import { GuardianLink } from '../../entities/guardian.entity';
import { LocationSharing } from '../../entities/location.entity';
import { InviteCodesModule } from '../invite-codes/invite-codes.module';

@Module({
    imports: [
        TypeOrmModule.forFeature([Group, GroupMember, InviteCode, Trip, Schedule, GuardianLink, LocationSharing]),
        InviteCodesModule,
    ],
    controllers: [GroupsController],
    providers: [GroupsService],
    exports: [GroupsService],
})
export class GroupsModule { }
