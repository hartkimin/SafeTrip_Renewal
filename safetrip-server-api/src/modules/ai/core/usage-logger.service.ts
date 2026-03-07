import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AiUsageLog } from '../../../entities';

export interface AiLogEntry {
    userId?: string;
    tripId?: string;
    aiType: 'safety' | 'convenience' | 'intelligence';
    featureName: string;
    modelUsed?: string;
    latencyMs?: number;
    isCached?: boolean;
    isFallback?: boolean;
    fallbackReason?: string;
    isMinorUser?: boolean;
    privacyLevel?: string;
}

@Injectable()
export class UsageLoggerService {
    private readonly logger = new Logger(UsageLoggerService.name);

    constructor(
        @InjectRepository(AiUsageLog)
        private readonly logRepo: Repository<AiUsageLog>,
    ) {}

    async log(entry: AiLogEntry): Promise<AiUsageLog> {
        const retentionDays = entry.isMinorUser ? 30 : 90;
        const expiresAt = new Date();
        expiresAt.setDate(expiresAt.getDate() + retentionDays);

        const record = this.logRepo.create({
            userId: entry.userId ?? null,
            tripId: entry.tripId ?? null,
            aiType: entry.aiType,
            featureName: entry.featureName,
            modelUsed: entry.modelUsed ?? null,
            latencyMs: entry.latencyMs ?? null,
            isCached: entry.isCached ?? false,
            isFallback: entry.isFallback ?? false,
            fallbackReason: entry.fallbackReason ?? null,
            isMinorUser: entry.isMinorUser ?? false,
            privacyLevel: entry.privacyLevel ?? null,
            expiresAt,
        });

        return this.logRepo.save(record);
    }

    async updateFeedback(logId: string, feedback: -1 | 0 | 1): Promise<void> {
        await this.logRepo.update(logId, { feedback });
    }
}
