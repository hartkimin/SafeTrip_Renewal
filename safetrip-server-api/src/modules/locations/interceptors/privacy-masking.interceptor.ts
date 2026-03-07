import {
    Injectable,
    NestInterceptor,
    ExecutionContext,
    CallHandler,
    Logger,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { DataSource } from 'typeorm';
import { MovementHistoryAccess } from '../guards/movement-history-access.guard';

/**
 * PrivacyMaskingInterceptor -- SS8 프라이버시 마스킹
 *
 * 위치 데이터 응답에 대해 trip의 privacy_level에 따른 마스킹 처리.
 *
 * Rules:
 *   M1 Transparency: role === 'self' -> NO masking (bypass)
 *   safety_first:    No masking
 *   standard:        Address masked to road level (first 3 parts + "인근")
 *   privacy_first:
 *     - During sharing schedule: Address masked to district level (first 2 parts)
 *     - Outside sharing schedule: 500m grid snap + district address + is_masked = true
 *   SOS override:    If SOS active, unmask +/-30 minutes around SOS activation time
 */
@Injectable()
export class PrivacyMaskingInterceptor implements NestInterceptor {
    private readonly logger = new Logger(PrivacyMaskingInterceptor.name);

    /** 1 degree latitude ~ 111,320 meters */
    private static readonly METERS_PER_DEGREE = 111_320;

    constructor(private readonly dataSource: DataSource) {}

    intercept(
        context: ExecutionContext,
        next: CallHandler,
    ): Observable<any> {
        const request = context.switchToHttp().getRequest();
        const access: MovementHistoryAccess | undefined =
            request.movementHistoryAccess;
        const tripId: string | undefined = request.params.tripId;
        const targetUserId: string | undefined =
            request.params.targetUserId || request.params.userId;

        return next.handle().pipe(
            map(async (responseData) => {
                try {
                    return await this.applyMasking(
                        responseData,
                        access,
                        tripId,
                        targetUserId,
                    );
                } catch (err) {
                    this.logger.error(
                        `Privacy masking failed, returning original data: ${err.message}`,
                        err.stack,
                    );
                    return responseData;
                }
            }),
        );
    }

    // ----------------------------------------------------------------
    // Core masking logic
    // ----------------------------------------------------------------

    private async applyMasking(
        responseData: any,
        access: MovementHistoryAccess | undefined,
        tripId: string | undefined,
        targetUserId: string | undefined,
    ): Promise<any> {
        // M1 Transparency: self-access bypasses all masking
        if (access?.role === 'self') {
            return responseData;
        }

        // Cannot mask without trip context
        if (!tripId || !targetUserId) {
            return responseData;
        }

        // Fetch trip privacy level
        const privacyLevel = await this.getPrivacyLevel(tripId);
        if (!privacyLevel || privacyLevel === 'safety_first') {
            return responseData;
        }

        // Fetch active SOS for override window
        const activeSos = await this.getActiveSos(targetUserId);

        // Fetch sharing schedules for privacy_first
        const schedules =
            privacyLevel === 'privacy_first'
                ? await this.getSharingSchedules(tripId, targetUserId)
                : [];

        // Extract location array from various response shapes
        const locations = this.extractLocations(responseData);
        if (!locations || locations.length === 0) {
            return responseData;
        }

        // Apply masking to each location object
        for (const loc of locations) {
            this.maskLocation(loc, privacyLevel, schedules, activeSos);
        }

        return responseData;
    }

    /**
     * Mask a single location object in place based on privacy_level.
     */
    private maskLocation(
        loc: any,
        privacyLevel: string,
        schedules: any[],
        activeSos: { sosId: string; activatedAt: Date } | null,
    ): void {
        const recordedAt = this.parseRecordedAt(loc);

        // SOS override: unmask +/-30 min around SOS activation
        if (activeSos && recordedAt) {
            const sosTime = activeSos.activatedAt.getTime();
            const locTime = recordedAt.getTime();
            const thirtyMinMs = 30 * 60 * 1000;
            if (
                locTime >= sosTime - thirtyMinMs &&
                locTime <= sosTime + thirtyMinMs
            ) {
                // SOS override -- no masking for this record
                return;
            }
        }

        if (privacyLevel === 'standard') {
            // Standard: mask address to road level
            loc.address = this.maskToRoadLevel(loc.address);
            return;
        }

        if (privacyLevel === 'privacy_first') {
            const withinSchedule = this.isWithinSchedule(
                recordedAt,
                schedules,
            );

            if (withinSchedule) {
                // During sharing schedule: district-level address only
                loc.address = this.maskToDistrictLevel(loc.address);
            } else {
                // Outside sharing schedule: grid snap + district address + flag
                if (typeof loc.latitude === 'number') {
                    loc.latitude = this.snapToGrid(loc.latitude, 500);
                }
                if (typeof loc.longitude === 'number') {
                    loc.longitude = this.snapToGrid(loc.longitude, 500);
                }
                loc.address = this.maskToDistrictLevel(loc.address);
                loc.is_masked = true;
            }
        }
    }

    // ----------------------------------------------------------------
    // Helper: coordinate grid-snap
    // ----------------------------------------------------------------

    /**
     * Snap a coordinate value to a grid of the given size in meters.
     * Uses 1 degree ~ 111,320 m approximation.
     */
    snapToGrid(coord: number, gridMeters: number): number {
        const gridDegrees =
            gridMeters / PrivacyMaskingInterceptor.METERS_PER_DEGREE;
        return Math.round(coord / gridDegrees) * gridDegrees;
    }

    // ----------------------------------------------------------------
    // Helper: address masking
    // ----------------------------------------------------------------

    /**
     * Keep the first 3 space-separated parts of the address + "인근".
     * e.g. "서울특별시 강남구 테헤란로 123" -> "서울특별시 강남구 테헤란로 인근"
     */
    maskToRoadLevel(address: string | null): string | null {
        if (!address) return address;
        const parts = address.trim().split(/\s+/);
        if (parts.length <= 3) return address;
        return parts.slice(0, 3).join(' ') + ' 인근';
    }

    /**
     * Keep the first 2 space-separated parts of the address.
     * e.g. "서울특별시 강남구 테헤란로 123" -> "서울특별시 강남구"
     */
    maskToDistrictLevel(address: string | null): string | null {
        if (!address) return address;
        const parts = address.trim().split(/\s+/);
        if (parts.length <= 2) return address;
        return parts.slice(0, 2).join(' ');
    }

    // ----------------------------------------------------------------
    // Helper: schedule check
    // ----------------------------------------------------------------

    /**
     * Check whether a given recorded_at timestamp falls within any
     * sharing schedule for the trip+user.
     */
    isWithinSchedule(recordedAt: Date | null, schedules: any[]): boolean {
        if (!recordedAt || schedules.length === 0) {
            // Default to within-schedule when no schedules configured (safe default)
            return true;
        }

        const dayOfWeek = recordedAt.getDay(); // 0=Sun .. 6=Sat
        const timeStr =
            recordedAt.getHours().toString().padStart(2, '0') +
            ':' +
            recordedAt.getMinutes().toString().padStart(2, '0');
        const dateStr = recordedAt.toISOString().split('T')[0]; // YYYY-MM-DD

        for (const sched of schedules) {
            if (!sched.is_sharing_on) continue;

            // Check if schedule applies to this day
            const matchesDay =
                sched.day_of_week === null && sched.specific_date === null; // daily
            const matchesDayOfWeek = sched.day_of_week === dayOfWeek;
            const matchesSpecificDate =
                sched.specific_date &&
                sched.specific_date.toISOString?.().split('T')[0] === dateStr;

            if (!matchesDay && !matchesDayOfWeek && !matchesSpecificDate) {
                continue;
            }

            // Check time range (share_start <= time <= share_end)
            const start = (sched.share_start || '').substring(0, 5); // "HH:MM"
            const end = (sched.share_end || '').substring(0, 5);
            if (timeStr >= start && timeStr <= end) {
                return true;
            }
        }

        return false;
    }

    // ----------------------------------------------------------------
    // Data extraction helpers
    // ----------------------------------------------------------------

    /**
     * Extract an array of location objects from varying response shapes:
     *   - Array of locations directly
     *   - Object with `locations` property
     *   - Object with `data` containing locations array or object with `locations`
     *   - Single location object (latitude/longitude present)
     */
    private extractLocations(responseData: any): any[] | null {
        if (!responseData) return null;

        // Unwrap success envelope: { success, data }
        const payload = responseData.data !== undefined
            ? responseData.data
            : responseData;

        if (Array.isArray(payload)) {
            return payload;
        }

        if (payload && Array.isArray(payload.locations)) {
            return payload.locations;
        }

        // Single location object
        if (
            payload &&
            typeof payload === 'object' &&
            (payload.latitude !== undefined || payload.longitude !== undefined)
        ) {
            return [payload];
        }

        return null;
    }

    /**
     * Parse recorded_at / recordedAt from a location object.
     */
    private parseRecordedAt(loc: any): Date | null {
        const raw = loc.recordedAt || loc.recorded_at;
        if (!raw) return null;
        if (raw instanceof Date) return raw;
        const parsed = new Date(raw);
        return isNaN(parsed.getTime()) ? null : parsed;
    }

    // ----------------------------------------------------------------
    // DB queries (raw SQL via DataSource)
    // ----------------------------------------------------------------

    private async getPrivacyLevel(tripId: string): Promise<string | null> {
        const rows = await this.dataSource.query(
            `SELECT privacy_level FROM tb_trip WHERE trip_id = $1`,
            [tripId],
        );
        return rows.length > 0 ? rows[0].privacy_level : null;
    }

    private async getActiveSos(
        userId: string,
    ): Promise<{ sosId: string; activatedAt: Date } | null> {
        const rows = await this.dataSource.query(
            `SELECT sos_id, activated_at
               FROM tb_sos
              WHERE user_id = $1
                AND status = 'active'
              ORDER BY activated_at DESC
              LIMIT 1`,
            [userId],
        );
        if (rows.length === 0) return null;
        return {
            sosId: rows[0].sos_id,
            activatedAt: new Date(rows[0].activated_at),
        };
    }

    private async getSharingSchedules(
        tripId: string,
        userId: string,
    ): Promise<any[]> {
        return this.dataSource.query(
            `SELECT share_start,
                    share_end,
                    day_of_week,
                    specific_date,
                    is_sharing_on
               FROM tb_location_schedule
              WHERE trip_id = $1
                AND user_id = $2`,
            [tripId, userId],
        );
    }
}
