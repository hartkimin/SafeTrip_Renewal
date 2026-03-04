import { Controller, Get, Post, Patch, Delete, Param, Body, Query, Req, BadRequestException, NotFoundException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery, ApiParam } from '@nestjs/swagger';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { GeofencesService } from './geofences.service';

@ApiTags('Geofences')
@ApiBearerAuth('firebase-auth')
@Controller()
export class GeofencesController {
    constructor(private readonly geofencesService: GeofencesService) { }

    @Post('groups/:group_id/geofences')
    @ApiOperation({ summary: '10.1 지오펜스 생성' })
    @ApiParam({ name: 'group_id', type: 'string' })
    async createGeofence(
        @Param('group_id') groupId: string, 
        @CurrentUser() userId: string, 
        @Body() body: any
    ) {
        const { name, type, shape_type } = body;
        if (!name || !type || !shape_type) {
            throw new BadRequestException('name, type, and shape_type are required');
        }

        if (shape_type === 'circle') {
            if (body.center_latitude === undefined || body.center_longitude === undefined || body.radius_meters === undefined) {
                throw new BadRequestException('center_latitude, center_longitude, and radius_meters are required for circle geofence');
            }
        } else if (shape_type === 'polygon') {
            if (!body.polygon_coordinates) {
                throw new BadRequestException('polygon_coordinates is required for polygon geofence');
            }
        }

        // Service uses tripId, but route uses group_id. 
        // In this project, they are often linked 1:1. 
        // For consistency with service, we pass it as tripId/groupId.
        const geofence = await this.geofencesService.create(userId, groupId, body);
        return {
            success: true,
            data: {
                geofence_id: geofence.geofenceId
            },
            message: 'Geofence created successfully'
        };
    }

    @Get('geofences')
    @ApiOperation({ summary: '10.2 지오펜스 목록 조회' })
    @ApiQuery({ name: 'group_id', type: 'string', required: true })
    async getGeofences(@Query('group_id') groupId: string) {
        if (!groupId) {
            throw new BadRequestException('group_id is required');
        }

        const geofences = await this.geofencesService.findByTrip(groupId);
        return {
            success: true,
            data: {
                geofences: geofences,
                total: geofences.length
            }
        };
    }

    @Get('geofences/:id')
    @ApiOperation({ summary: '10.3 지오펜스 상세 조회' })
    @ApiParam({ name: 'id', type: 'string' })
    async getGeofenceDetail(@Param('id') id: string) {
        // Implementation for single find might be needed in service, 
        // but we can filter from findByTrip or add to service.
        const geofences = await this.geofencesService.findByTrip(''); // dummy tripId to reuse service for now or find all
        const geofence = geofences.find(g => g.geofenceId === id);
        
        if (!geofence) {
            throw new NotFoundException('Geofence not found');
        }

        return {
            success: true,
            data: geofence
        };
    }

    @Patch('geofences/:id')
    @ApiOperation({ summary: '10.4 지오펜스 수정' })
    @ApiParam({ name: 'id', type: 'string' })
    async updateGeofence(@Param('id') id: string, @Body() body: any) {
        if (body.center_latitude !== undefined && (body.center_latitude < -90 || body.center_latitude > 90)) {
            throw new BadRequestException('Invalid center_latitude');
        }
        if (body.center_longitude !== undefined && (body.center_longitude < -180 || body.center_longitude > 180)) {
            throw new BadRequestException('Invalid center_longitude');
        }

        const updated = await this.geofencesService.update(id, body);
        if (!updated) {
            throw new NotFoundException('Geofence not found');
        }

        return {
            success: true,
            data: {
                geofence_id: updated.geofenceId
            },
            message: 'Geofence updated successfully'
        };
    }

    @Delete('geofences/:id')
    @ApiOperation({ summary: '10.5 지오펜스 삭제' })
    @ApiParam({ name: 'id', type: 'string' })
    async deleteGeofence(@Param('id') id: string) {
        await this.geofencesService.delete(id);
        return {
            success: true,
            data: {
                geofence_id: id
            },
            message: 'Geofence deleted successfully'
        };
    }

    @Post('geofences/events')
    @ApiOperation({ summary: '10.6 지오펜스 이벤트 기록' })
    async recordEvent(@CurrentUser() userId: string, @Body() body: any) {
        const { geofence_id, trip_id, action, latitude, longitude } = body;

        if (!geofence_id || !action || latitude === undefined || longitude === undefined) {
            throw new BadRequestException('geofence_id, action, latitude, and longitude are required');
        }

        const event = await this.geofencesService.recordEvent(
            geofence_id,
            userId,
            trip_id || '',
            action,
            latitude,
            longitude
        );

        return {
            success: true,
            data: event,
            message: 'Geofence event recorded'
        };
    }
}
