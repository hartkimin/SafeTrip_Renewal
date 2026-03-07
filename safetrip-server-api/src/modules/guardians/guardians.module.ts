import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GuardiansController } from './guardians.controller';
import { GuardiansService } from './guardians.service';
import {
    Guardian, GuardianLink, GuardianPause,
    GuardianLocationRequest, GuardianSnapshot, GuardianReleaseRequest,
} from '../../entities/guardian.entity';
import { User } from '../../entities/user.entity';
import { GroupMember } from '../../entities/group-member.entity';
import { Schedule } from '../../entities/schedule.entity';
import { PaymentsModule } from '../payments/payments.module';

@Module({
    imports: [
        TypeOrmModule.forFeature([Guardian, GuardianLink, GuardianPause, GuardianLocationRequest, GuardianSnapshot, GuardianReleaseRequest, User, GroupMember, Schedule]),
        PaymentsModule
    ],
    controllers: [GuardiansController],
    providers: [GuardiansService],
    exports: [GuardiansService],
})
export class GuardiansModule { }
