import { Injectable, Logger } from '@nestjs/common';
import { SafetyAiService } from './safety-ai.service';
import { ConvenienceAiService } from './convenience-ai.service';
import { IntelligenceAiService } from './intelligence-ai.service';
import { AccessGuardService, AiFeature } from './core/access-guard.service';

/**
 * AiService -- backward-compatible orchestrator
 * New code should inject specific services directly.
 */
@Injectable()
export class AiService {
    private readonly logger = new Logger(AiService.name);

    constructor(
        private readonly safetyAi: SafetyAiService,
        private readonly convenienceAi: ConvenienceAiService,
        private readonly intelligenceAi: IntelligenceAiService,
        private readonly accessGuard: AccessGuardService,
    ) {}

    async checkAccess(userId: string, feature: AiFeature, tripId?: string) {
        return this.accessGuard.checkAccess(userId, feature, tripId);
    }
}
