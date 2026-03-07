import { Injectable } from '@nestjs/common';

@Injectable()
export class DataMaskerService {
    maskText(text: string): string {
        let masked = text;
        masked = masked.replace(/(\+?\d{1,4}[\s-]?)?\(?\d{2,4}\)?[\s.-]?\d{3,4}[\s.-]?\d{3,4}/g, '[PHONE]');
        masked = masked.replace(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g, '[EMAIL]');
        return masked;
    }

    anonymizeNames(names: string[]): string[] {
        return names.map((_, i) => `멤버${String.fromCharCode(65 + i)}`);
    }

    coarsenLocation(lat: number, lng: number): { latitude: number; longitude: number } {
        return {
            latitude: Math.round(lat * 100) / 100,
            longitude: Math.round(lng * 100) / 100,
        };
    }

    maskTripName(tripName: string, tripId: string): string {
        return `trip_${tripId.split('-')[0]}`;
    }
}
