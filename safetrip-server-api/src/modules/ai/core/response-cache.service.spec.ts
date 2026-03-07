import { ResponseCacheService } from './response-cache.service';

describe('ResponseCacheService', () => {
    let service: ResponseCacheService;
    beforeEach(() => { service = new ResponseCacheService(); });
    afterEach(() => { service.clearAll(); });

    it('should return null for cache miss', () => { expect(service.get('x')).toBeNull(); });
    it('should cache and retrieve', () => {
        service.set('k', { data: 'test' }, 60000);
        expect(service.get('k')).toEqual({ data: 'test' });
    });
    it('should return null for expired entry', () => {
        service.set('expired', 'old', -1);
        expect(service.get('expired')).toBeNull();
    });
    it('should build correct cache key', () => {
        expect(service.buildKey('country_threat', { country_code: 'JP', threat_type: 'crime' })).toBe('country_threat:JP:crime');
    });
    it('should return correct TTL per feature', () => {
        expect(service.getTtl('country_threat')).toBe(6 * 60 * 60 * 1000);
        expect(service.getTtl('place_recommend')).toBe(24 * 60 * 60 * 1000);
        expect(service.getTtl('schedule_autocomplete')).toBe(1 * 60 * 60 * 1000);
        expect(service.getTtl('safety_briefing')).toBe(4 * 60 * 60 * 1000);
    });
    it('should delete specific key', () => {
        service.set('k', 'v', 60000);
        service.delete('k');
        expect(service.get('k')).toBeNull();
    });
});
