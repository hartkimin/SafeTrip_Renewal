import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { APP_GUARD } from '@nestjs/core';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { FirebaseAuthGuard } from '../../common/guards/firebase-auth.guard';
import { User, ParentalConsent } from '../../entities/user.entity';
import { Guardian, GuardianLink } from '../../entities/guardian.entity';
import { UserConsent } from '../../entities/legal.entity';

@Module({
    imports: [TypeOrmModule.forFeature([User, ParentalConsent, Guardian, GuardianLink, UserConsent])],
    controllers: [AuthController],
    providers: [
        AuthService,
        {
            provide: APP_GUARD,
            useClass: FirebaseAuthGuard,
        },
    ],
    exports: [AuthService],
})
export class AuthModule { }
