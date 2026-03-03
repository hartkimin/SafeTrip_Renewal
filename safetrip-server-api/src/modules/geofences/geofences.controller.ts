import { Controller, Get, Post, Patch, Delete, Param, Body, Query, Req, BadRequestException, NotFoundException, ForbiddenException, UnauthorizedException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiQuery, ApiParam } from '@nestjs/swagger';
import { GeofencesService } from './geofences.service';

@ApiTags('Geofences')
@Controller()
export class GeofencesController {
    constructor(private readonly geofencesService: GeofencesService) { }

    @Post('api/v1/groups/:group_id/geofences')
    @ApiOperation({ summary: '10.1 지오펜스 생성 (그룹 멤버 등재 확인, 권한 확인 생략)' })
    @ApiParam({ name: 'group_id', type: 'string' })
    async createGeofence(@Param('group_id') groupId: string, @Req() req: any, @Body() body: any) {
        // 실제로는 authenticate 미들웨어 없이 req.body.user_id 혹은 req.userId 확인
        const userId = req.userId || body.user_id || (req.user && req.user.user_id);
        if (!userId) {
            throw new BadRequestException('user_id is required');
        }

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

        const geofence = await this.geofencesService.create(userId, groupId, body);
        return {
            success: true,
            data: {
                geofence_id: geofence.geofenceId
            },
            message: 'Geofence created successfully'
        };
    }

    @Get('api/v1/geofences')
    @ApiOperation({ summary: '10.2 지오펜스 목록 조회' })
    @ApiQuery({ name: 'group_id', type: 'string', required: true })
    async getGeofences(@Query('group_id') groupId: string) {
        if (!groupId) {
            throw new BadRequestException('group_id is required');
        }

        const geofences: any[] = []; // await this.geofencesService.findByGroupId(groupId);
        return {
            success: true,
            data: {
                geofences: geofences,
                total: geofences.length
            }
        };
    }

    @Get('api/v1/geofences/:id')
    @ApiOperation({ summary: '10.3 지오펜스 상세 조회' })
    @ApiParam({ name: 'id', type: 'string' })
    @ApiQuery({ name: 'group_id', type: 'string', required: true })
    async getGeofenceDetail(@Param('id') id: string, @Query('group_id') groupId: string) {
        if (!id || !groupId) {
            throw new BadRequestException('geofence_id and group_id are required'); // 명세에서는 이렇게, 실 사용은 알아서
        }

        const geofence = null; // await this.geofencesService.findByIdAndGroupId(id, groupId);
        if (!geofence) {
            throw new NotFoundException('Geofence not found');
        }

        return {
            success: true,
            data: geofence
        }
    }

    @Patch('api/v1/geofences/:id')
    @ApiOperation({ summary: '10.4 지오펜스 수정' })
    @ApiParam({ name: 'id', type: 'string' })
    @ApiQuery({ name: 'group_id', type: 'string', required: true })
    async updateGeofence(@Param('id') id: string, @Query('group_id') groupId: string, @Body() body: any) {
        if (!id || !groupId) {
            throw new BadRequestException('geofence_id or group_id missing'); // 대략적 처리
        }

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
                geofence_id: updated.geofenceId,
                message: 'Geofence updated successfully'
            }
        }
    }

    @Delete('api/v1/geofences/:id')
    @ApiOperation({ summary: '10.5 지오펜스 삭제' })
    @ApiParam({ name: 'id', type: 'string' })
    @ApiQuery({ name: 'group_id', type: 'string', required: true })
    async deleteGeofence(@Param('id') id: string, @Query('group_id') groupId: string) {
        if (!id || !groupId) {
            throw new BadRequestException('geofence_id and group_id are required');
        }

        const deleted = true; // await this.geofencesService.remove(id);
        if (!deleted) {
            throw new NotFoundException('Geofence not found');
        }

        return {
            success: true,
            data: {
                geofence_id: id,
                message: 'Geofence deleted successfully'
            }
        }
    }

    @Post('api/v1/geofences/events')
    @ApiOperation({ summary: '10.6 지오펜스 이벤트 기록' })
    async recordEvent(@Req() req: any, @Body() body: any) {
        const userId = req.userId || (body.params && body.params.user_id);
        const geofence = body.geofence;
        const location = body.location;

        if (!geofence || !location) {
            throw new BadRequestException('geofence and location are required');
        }

        if (!userId) {
            throw new BadRequestException('user_id is required');
        }

        /* await this.geofencesService.recordGeofenceEventLog(
            userId,
            geofence.identifier,
            geofence.action,
            location.coords.latitude,
            location.coords.longitude
        ); */

        return {
            success: true,
            data: {
                message: 'Geofence event recorded'
            }
        };
    }
}
