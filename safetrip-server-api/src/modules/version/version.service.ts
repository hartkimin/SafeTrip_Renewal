import { Injectable } from '@nestjs/common';

export interface VersionCheckResult {
    min_version: string;
    recommended_version: string;
    update_type: 'none' | 'optional' | 'critical';
    store_url: string;
}

@Injectable()
export class VersionService {
    private readonly minVersion = process.env.APP_MIN_VERSION || '1.0.0';
    private readonly recommendedVersion = process.env.APP_RECOMMENDED_VERSION || '1.1.0';

    private readonly storeUrls: Record<string, string> = {
        android: 'https://play.google.com/store/apps/details?id=com.urock.safe.trip',
        ios: 'https://apps.apple.com/app/safetrip/id000000000',
    };

    check(platform: string, currentVersion: string): VersionCheckResult {
        const storeUrl = this.storeUrls[platform] || this.storeUrls['android'];

        if (this.compareVersions(currentVersion, this.minVersion) < 0) {
            return { min_version: this.minVersion, recommended_version: this.recommendedVersion, update_type: 'critical', store_url: storeUrl };
        }
        if (this.compareVersions(currentVersion, this.recommendedVersion) < 0) {
            return { min_version: this.minVersion, recommended_version: this.recommendedVersion, update_type: 'optional', store_url: storeUrl };
        }
        return { min_version: this.minVersion, recommended_version: this.recommendedVersion, update_type: 'none', store_url: storeUrl };
    }

    private compareVersions(a: string, b: string): number {
        const pa = a.split('.').map(Number);
        const pb = b.split('.').map(Number);
        const len = Math.max(pa.length, pb.length);
        for (let i = 0; i < len; i++) {
            const na = pa[i] || 0;
            const nb = pb[i] || 0;
            if (na !== nb) return na - nb;
        }
        return 0;
    }
}
