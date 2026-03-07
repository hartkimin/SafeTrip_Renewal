import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { InviteCode } from '../../entities/invite-code.entity';
import { Group } from '../../entities/group.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Trip } from '../../entities/trip.entity';
import { InviteCodesController } from './invite-codes.controller';
import { InviteCodesService } from './invite-codes.service';

@Module({
    imports: [TypeOrmModule.forFeature([InviteCode, Group, GroupMember, Trip])],
    controllers: [InviteCodesController],
    providers: [InviteCodesService],
    exports: [InviteCodesService],
})
export class InviteCodesModule {}
