import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { User } from '../../entities/user.entity';
import { FcmToken } from '../../entities/notification.entity';
import { Guardian, GuardianLink } from '../../entities/guardian.entity';

@Module({
    imports: [TypeOrmModule.forFeature([User, FcmToken, Guardian, GuardianLink])],
    controllers: [UsersController],
    providers: [UsersService],
    exports: [UsersService],
})
export class UsersModule { }
