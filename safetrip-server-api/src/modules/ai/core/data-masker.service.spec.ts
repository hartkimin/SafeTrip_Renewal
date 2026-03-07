import { DataMaskerService } from './data-masker.service';

describe('DataMaskerService', () => {
    let service: DataMaskerService;
    beforeEach(() => { service = new DataMaskerService(); });

    describe('maskText', () => {
        it('should replace phone numbers with [PHONE]', () => {
            expect(service.maskText('Call 010-1234-5678')).toContain('[PHONE]');
            expect(service.maskText('Call 010-1234-5678')).not.toContain('010-1234-5678');
        });
        it('should replace emails with [EMAIL]', () => {
            expect(service.maskText('Email user@example.com')).toContain('[EMAIL]');
            expect(service.maskText('Email user@example.com')).not.toContain('user@example.com');
        });
        it('should not alter text without PII', () => {
            expect(service.maskText('Visit the Eiffel Tower')).toBe('Visit the Eiffel Tower');
        });
    });

    describe('anonymizeNames', () => {
        it('should replace names with sequential labels', () => {
            expect(service.anonymizeNames(['김철수', '이영희', '박지민'])).toEqual(['멤버A', '멤버B', '멤버C']);
        });
    });

    describe('coarsenLocation', () => {
        it('should round to ~1km grid', () => {
            const result = service.coarsenLocation(37.5665, 126.9780);
            expect(result.latitude).toBe(37.57);
            expect(result.longitude).toBe(126.98);
        });
    });

    describe('maskTripName', () => {
        it('should replace trip name with internal ID', () => {
            expect(service.maskTripName('파리여행', 'a1b2c3d4-e5f6-7890-abcd-ef1234567890')).toBe('trip_a1b2c3d4');
        });
    });
});
