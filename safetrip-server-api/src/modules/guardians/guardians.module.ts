import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { GuardiansController } from './guardians.controller';
import { GuardiansService } from './guardians.service';
import {
    Guardian, GuardianLink, GuardianPause,
    GuardianLocationRequest, GuardianSnapshot,
} from '../../entities/guardian.entity';
import { User } from '../../entities/user.entity';

@Module({
    imports: [TypeOrmModule.forFeature([Guardian, GuardianLink, GuardianPause, GuardianLocationRequest, GuardianSnapshot, User])],
    controllers: [GuardiansController],
    providers: [GuardiansService],
    exports: [GuardiansService],
})
export class GuardiansModule { }
