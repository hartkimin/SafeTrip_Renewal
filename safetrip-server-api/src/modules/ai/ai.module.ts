import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HttpModule } from '@nestjs/axios';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { AiUsage, User, Payment, Trip } from '../../entities';
import { PaymentsModule } from '../payments/payments.module';

@Module({
    imports: [
        TypeOrmModule.forFeature([AiUsage, User, Payment, Trip]),
        PaymentsModule,
        HttpModule,
    ],
    controllers: [AiController],
    providers: [AiService],
    exports: [AiService],
})
export class AiModule { }
