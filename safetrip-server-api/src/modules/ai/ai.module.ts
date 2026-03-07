import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HttpModule } from '@nestjs/axios';
import { AiController } from './ai.controller';
import { AiService } from './ai.service';
import { AccessGuardService } from './core/access-guard.service';
import { LLMGatewayService } from './core/llm-gateway.service';
import { DataMaskerService } from './core/data-masker.service';
import { ResponseCacheService } from './core/response-cache.service';
import { UsageLoggerService } from './core/usage-logger.service';
import { SafetyAiService } from './safety-ai.service';
import { ConvenienceAiService } from './convenience-ai.service';
import { IntelligenceAiService } from './intelligence-ai.service';
import { AiUsage, AiUsageLog, AiSubscription, User, GroupMember, Trip, Payment } from '../../entities';
import { PaymentsModule } from '../payments/payments.module';

@Module({
    imports: [
        TypeOrmModule.forFeature([
            AiUsage, AiUsageLog, AiSubscription,
            User, GroupMember, Trip, Payment,
        ]),
        PaymentsModule,
        HttpModule,
    ],
    controllers: [AiController],
    providers: [
        AiService,
        AccessGuardService,
        LLMGatewayService,
        DataMaskerService,
        ResponseCacheService,
        UsageLoggerService,
        SafetyAiService,
        ConvenienceAiService,
        IntelligenceAiService,
    ],
    exports: [
        AiService,
        AccessGuardService,
        SafetyAiService,
        ConvenienceAiService,
        IntelligenceAiService,
    ],
})
export class AiModule {}
