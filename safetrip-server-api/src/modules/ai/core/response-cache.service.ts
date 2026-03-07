import { Injectable } from '@nestjs/common';

interface CacheEntry { value: any; expiresAt: number; }

@Injectable()
export class ResponseCacheService {
    private readonly cache = new Map<string, CacheEntry>();
    private readonly ttlMap: Record<string, number> = {
        country_threat: 6 * 60 * 60 * 1000,
        place_recommend: 24 * 60 * 60 * 1000,
        schedule_autocomplete: 1 * 60 * 60 * 1000,
        chat_summary: Infinity,
        safety_briefing: 4 * 60 * 60 * 1000,
    };

    get(key: string): any | null {
        const entry = this.cache.get(key);
        if (!entry) return null;
        if (Date.now() > entry.expiresAt) { this.cache.delete(key); return null; }
        return entry.value;
    }

    set(key: string, value: any, ttlMs: number): void {
        this.cache.set(key, { value, expiresAt: Date.now() + ttlMs });
    }

    delete(key: string): void { this.cache.delete(key); }
    clearAll(): void { this.cache.clear(); }

    getTtl(feature: string): number {
        return this.ttlMap[feature] ?? 60 * 60 * 1000;
    }

    buildKey(feature: string, params: Record<string, any>): string {
        return `${feature}:${Object.values(params).map(String).join(':')}`;
    }
}
