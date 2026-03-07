import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { User } from '../../entities/user.entity';
import { FcmToken } from '../../entities/notification.entity';
import { Guardian, GuardianLink } from '../../entities/guardian.entity';
import { EmergencyContact } from '../../entities/emergency.entity';
import { GroupMember } from '../../entities/group-member.entity';

@Module({
    imports: [TypeOrmModule.forFeature([User, FcmToken, Guardian, GuardianLink, EmergencyContact, GroupMember])],
    controllers: [UsersController],
    providers: [UsersService],
    exports: [UsersService],
})
export class UsersModule { }
