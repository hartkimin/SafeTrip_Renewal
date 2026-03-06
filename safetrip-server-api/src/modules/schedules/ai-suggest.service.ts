import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Trip } from '../../entities/trip.entity';

export interface SuggestedSchedule {
    title: string;
    description: string;
    schedule_type: string;
    start_time: string;
    end_time: string;
    location_name?: string;
}

@Injectable()
export class AiSuggestService {
    constructor(
        @InjectRepository(Trip)
        private tripRepo: Repository<Trip>,
    ) {}

    async suggest(
        tripId: string,
        prompt?: string,
    ): Promise<{ suggestions: SuggestedSchedule[] }> {
        const trip = await this.tripRepo.findOne({ where: { tripId } });
        if (!trip) {
            return { suggestions: [] };
        }

        // Stub: Return sample suggestions based on destination
        // In production, this would call Claude API
        const destination =
            trip.destinationCity || trip.countryName || 'Unknown';

        return {
            suggestions: [
                {
                    title: `${destination} 도착 / 체크인`,
                    description: `${destination}에 도착하여 숙소 체크인`,
                    schedule_type: 'stay',
                    start_time: '14:00',
                    end_time: '15:00',
                    location_name: `${destination} 호텔`,
                },
                {
                    title: `${destination} 시내 관광`,
                    description: `${destination}의 주요 관광지 탐방`,
                    schedule_type: 'sightseeing',
                    start_time: '10:00',
                    end_time: '12:00',
                },
                {
                    title: '현지 맛집 탐방',
                    description: `${destination} 인기 맛집에서 식사`,
                    schedule_type: 'meal',
                    start_time: '12:30',
                    end_time: '14:00',
                },
            ],
        };
    }
}
