import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TravelSchedule } from '../../entities/travel-schedule.entity';

export interface WeatherInfo {
    temp: number;
    description: string;
    icon: string;
    humidity: number;
}

@Injectable()
export class WeatherService {
    constructor(
        @InjectRepository(TravelSchedule)
        private scheduleRepo: Repository<TravelSchedule>,
    ) {}

    /**
     * Stub: returns mock weather data.
     * In production, this would call a real weather API (e.g., OpenWeatherMap).
     */
    async getWeather(lat: number, lng: number, date: string): Promise<WeatherInfo> {
        // Deterministic mock data based on lat/lng to simulate variety
        const seed = Math.abs(Math.round(lat * 10 + lng * 10)) % 5;
        const weatherOptions: WeatherInfo[] = [
            { temp: 22, description: '\uB9D1\uC74C', icon: '\u2600\uFE0F', humidity: 45 },
            { temp: 18, description: '\uAD6C\uB984 \uC870\uAE08', icon: '\u26C5', humidity: 60 },
            { temp: 15, description: '\uD750\uB9BC', icon: '\u2601\uFE0F', humidity: 70 },
            { temp: 12, description: '\uBE44', icon: '\uD83C\uDF27\uFE0F', humidity: 85 },
            { temp: 25, description: '\uB354\uC6C0', icon: '\uD83C\uDF24\uFE0F', humidity: 50 },
        ];
        return weatherOptions[seed];
    }

    /**
     * Get weather for a specific schedule by looking up its location.
     */
    async getWeatherForSchedule(scheduleId: string): Promise<WeatherInfo & { scheduleId: string }> {
        const schedule = await this.scheduleRepo.findOne({
            where: { travelScheduleId: scheduleId },
        });

        if (!schedule || schedule.deletedAt) {
            throw new NotFoundException('Schedule not found');
        }

        const lat = schedule.locationLat ?? 35.6762;  // Default: Tokyo
        const lng = schedule.locationLng ?? 139.6503;
        const date = schedule.scheduleDate
            ? new Date(schedule.scheduleDate).toISOString().split('T')[0]
            : new Date().toISOString().split('T')[0];

        const weather = await this.getWeather(lat, lng, date);

        return {
            scheduleId,
            ...weather,
        };
    }
}
