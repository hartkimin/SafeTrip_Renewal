import {
    Injectable,
    NotFoundException,
    BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ScheduleTemplate } from '../../entities/schedule-template.entity';
import { TravelSchedule } from '../../entities/travel-schedule.entity';
import { Trip } from '../../entities/trip.entity';
import { SchedulesService } from './schedules.service';

@Injectable()
export class ScheduleTemplateService {
    constructor(
        @InjectRepository(ScheduleTemplate)
        private templateRepo: Repository<ScheduleTemplate>,
        @InjectRepository(Trip)
        private tripRepo: Repository<Trip>,
        private schedulesService: SchedulesService,
    ) {}

    /**
     * GET templates, optionally filtered by category.
     */
    async getTemplates(category?: string): Promise<ScheduleTemplate[]> {
        if (category) {
            return this.templateRepo.find({
                where: { category },
                order: { createdAt: 'DESC' },
            });
        }
        return this.templateRepo.find({
            order: { createdAt: 'DESC' },
        });
    }

    /**
     * POST apply a template to a trip.
     * Creates schedules from template items starting at startDate.
     * Uses SchedulesService.createSchedule to leverage existing validation.
     */
    async applyTemplate(
        tripId: string,
        templateId: string,
        startDate: string,
        userId: string,
    ): Promise<TravelSchedule[]> {
        const template = await this.templateRepo.findOne({
            where: { id: templateId },
        });
        if (!template) {
            throw new NotFoundException('Template not found');
        }

        const trip = await this.tripRepo.findOne({ where: { tripId } });
        if (!trip) {
            throw new NotFoundException('Trip not found');
        }

        const items: any[] = template.items;
        if (!Array.isArray(items) || items.length === 0) {
            throw new BadRequestException('Template has no items');
        }

        const createdSchedules: TravelSchedule[] = [];

        for (const item of items) {
            const scheduleDate = startDate; // All items applied to startDate by default

            // Build start_time and end_time from HH:MM format
            let startTime: string | undefined;
            let endTime: string | undefined;

            if (item.start_time) {
                startTime = `${scheduleDate}T${item.start_time}:00`;
            }
            if (item.end_time) {
                endTime = `${scheduleDate}T${item.end_time}:00`;
            }

            const schedule = await this.schedulesService.createSchedule(
                tripId,
                userId,
                {
                    title: item.title,
                    schedule_date: scheduleDate,
                    schedule_type: item.schedule_type || 'other',
                    start_time: startTime,
                    end_time: endTime,
                    description: item.description,
                    location_name: item.location_name,
                },
            );
            createdSchedules.push(schedule);
        }

        return createdSchedules;
    }
}
