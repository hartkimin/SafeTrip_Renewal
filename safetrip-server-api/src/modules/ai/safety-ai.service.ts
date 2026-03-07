import { Injectable, Logger } from '@nestjs/common';
import { AccessGuardService } from './core/access-guard.service';
import { UsageLoggerService } from './core/usage-logger.service';

/**
 * SafetyAiService -- Section 3.1 Safety AI
 *
 * - All users, free tier (no subscription required)
 * - NO LLM usage (Section 7.2 hallucination prevention)
 * - Rule-based + official data sources only
 *
 * Features:
 *   - departure_detect: gathering point departure (300m / 10min)
 *   - sos_auto_detect:  fall detection + inactivity timeout (15min)
 *   - speed anomaly:    abnormal speed > 150 km/h
 */
@Injectable()
export class SafetyAiService {
    private readonly logger = new Logger(SafetyAiService.name);

    /** Distance threshold for departure detection (meters) */
    private static readonly DEPARTURE_DISTANCE_M = 300;
    /** Duration threshold for departure detection (minutes) */
    private static readonly DEPARTURE_DURATION_MIN = 10;
    /** Inactivity threshold for SOS auto-trigger (minutes) */
    private static readonly SOS_INACTIVE_MIN = 15;
    /** Speed threshold for anomaly detection (m/s) -- 150 km/h */
    private static readonly SPEED_ANOMALY_MS = 41.6;

    constructor(
        private readonly accessGuard: AccessGuardService,
        private readonly usageLogger: UsageLoggerService,
    ) {}

    /**
     * Section 13.2 -- Departure detection
     * Trigger: distance > 300m from gathering point AND duration >= 10 min
     */
    evaluateDeparture(data: {
        distanceFromGatheringM: number;
        durationOutsideMin: number;
    }): {
        isDeparted: boolean;
        severity: 'high' | 'none';
        distanceM: number;
        durationMin: number;
    } {
        const isDeparted =
            data.distanceFromGatheringM > SafetyAiService.DEPARTURE_DISTANCE_M &&
            data.durationOutsideMin >= SafetyAiService.DEPARTURE_DURATION_MIN;

        return {
            isDeparted,
            severity: isDeparted ? 'high' : 'none',
            distanceM: data.distanceFromGatheringM,
            durationMin: data.durationOutsideMin,
        };
    }

    /**
     * Section 13.2 -- SOS condition evaluation
     * Trigger: accelerometer fall detection OR 15+ min inactivity
     */
    evaluateSosCondition(data: {
        inactiveMinutes: number;
        hasFallDetected: boolean;
    }): {
        shouldTriggerSos: boolean;
        reason: 'fall_detected' | 'inactive_timeout' | 'none';
    } {
        if (data.hasFallDetected) {
            return { shouldTriggerSos: true, reason: 'fall_detected' };
        }
        if (data.inactiveMinutes >= SafetyAiService.SOS_INACTIVE_MIN) {
            return { shouldTriggerSos: true, reason: 'inactive_timeout' };
        }
        return { shouldTriggerSos: false, reason: 'none' };
    }

    /**
     * Abnormal speed detection (migrated from legacy anomaly detection)
     * Trigger: speed > 150 km/h (41.6 m/s)
     */
    evaluateSpeedAnomaly(speedMs: number): {
        isAnomalous: boolean;
        severity: 'medium' | 'none';
        speedKmh: number;
    } {
        const isAnomalous = speedMs > SafetyAiService.SPEED_ANOMALY_MS;
        return {
            isAnomalous,
            severity: isAnomalous ? 'medium' : 'none',
            speedKmh: Math.round(speedMs * 3.6),
        };
    }

    /**
     * Full pipeline: access guard check -> evaluate departure -> log usage
     */
    async checkDeparture(
        userId: string,
        tripId: string,
        data: { distanceFromGatheringM: number; durationOutsideMin: number },
    ) {
        const start = Date.now();

        await this.accessGuard.checkAccess(userId, 'departure_detect', tripId);

        const result = this.evaluateDeparture(data);

        await this.usageLogger.log({
            userId,
            tripId,
            aiType: 'safety',
            featureName: 'departure_detect',
            modelUsed: 'rule_based',
            latencyMs: Date.now() - start,
        });

        if (result.isDeparted) {
            this.logger.warn(
                `Departure detected: user=${userId} trip=${tripId} ` +
                `distance=${result.distanceM}m duration=${result.durationMin}min`,
            );
        }

        return result;
    }
}
