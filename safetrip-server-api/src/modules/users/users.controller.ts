import { Controller, Get, Patch, Post, Put, Delete, Body, Param, Query, HttpCode, HttpStatus, UnauthorizedException, BadRequestException, NotFoundException, ForbiddenException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiBody, ApiQuery } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { UsersService } from './users.service';

@ApiTags('Users')
@ApiBearerAuth('firebase-auth')
@Controller('users')
export class UsersController {
    constructor(private readonly usersService: UsersService) { }

    @Public()
    @Post('register')
    @HttpCode(HttpStatus.CREATED)
    @ApiOperation({ summary: '테스트용 사용자 등록' })
    @ApiBody({
        schema: {
            type: 'object',
            properties: {
                user_id: { type: 'string' },
                display_name: { type: 'string' },
                phone_number: { type: 'string' },
                phone_country_code: { type: 'string' },
            },
            required: ['user_id']
        }
    })
    async registerTestUser(
        @Body() body: { user_id: string; display_name?: string; phone_number?: string; phone_country_code?: string }
    ) {
        if (!body.user_id) throw new BadRequestException('user_id is required');

        const user = await this.usersService.registerTestUser(body);
        return {
            success: true,
            data: user,
            message: "User registered successfully"
        };
    }

    @Public()
    @Get('by-phone')
    @ApiOperation({ summary: '전화번호로 사용자 조회' })
    @ApiQuery({ name: 'phone_number', required: true })
    @ApiQuery({ name: 'phone_country_code', required: false })
    async getUserByPhone(
        @Query('phone_number') phoneNumber: string,
        @Query('phone_country_code') phoneCountryCode?: string
    ) {
        if (!phoneNumber) throw new BadRequestException('phone_number is required');

        let formattedPhone = phoneNumber;
        if (!phoneNumber.startsWith('+')) {
            if (!phoneCountryCode) {
                throw new BadRequestException('phone_country_code is required when phone_number is not E.164');
            }
            formattedPhone = `${phoneCountryCode}${phoneNumber}`;
        }

        const user = await this.usersService.findByPhone(formattedPhone, phoneCountryCode);
        return {
            success: true,
            data: user
        };
    }

    @Get('search')
    @ApiOperation({ summary: '사용자 검색' })
    @ApiQuery({ name: 'q', required: true })
    async searchUsers(
        @CurrentUser() userId: string,
        @Query('q') q: string
    ) {
        if (!q || q.length < 2) throw new BadRequestException('q must be at least 2 characters');

        const users = await this.usersService.searchUsers(q, userId);
        return {
            success: true,
            data: users
        };
    }

    @Get('me')
    @ApiOperation({ summary: '내 프로필 조회' })
    async getMyProfile(@CurrentUser() userId: string) {
        const user = await this.usersService.getProfile(userId);
        return {
            success: true,
            data: user
        };
    }

    @Patch('me')
    @ApiOperation({ summary: '내 프로필 수정' })
    async updateMyProfile(
        @CurrentUser() userId: string,
        @Body() body: { display_name?: string; profile_image_url?: string; date_of_birth?: string; location_sharing_mode?: string },
    ) {
        // Map snake_case keys to camelCase for the service
        const updateData: any = {};
        if (body.display_name !== undefined) updateData.displayName = body.display_name;
        if (body.profile_image_url !== undefined) updateData.profileImageUrl = body.profile_image_url;
        if (body.date_of_birth !== undefined) updateData.dateOfBirth = body.date_of_birth;
        if (body.location_sharing_mode !== undefined) updateData.locationSharingMode = body.location_sharing_mode;

        if (Object.keys(updateData).length === 0) {
            const user = await this.usersService.getProfile(userId);
            return { success: true, data: user };
        }

        const updatedUser = await this.usersService.updateProfile(userId, updateData);
        return {
            success: true,
            data: updatedUser
        };
    }

    @Patch('me/location-sharing')
    @ApiOperation({ summary: '위치 공유 모드 변경' })
    updateLocationSharing(
        @CurrentUser() userId: string,
        @Body() body: { mode: string },
    ) {
        return this.usersService.updateLocationSharingMode(userId, body.mode);
    }

    @Post('me/device')
    @ApiOperation({ summary: '디바이스 등록/갱신' })
    registerDevice(
        @CurrentUser() userId: string,
        @Body() body: { installId: string; deviceModel?: string; osType?: string; osVersion?: string; appVersion?: string },
    ) {
        return this.usersService.registerDevice(userId, body);
    }

    @Put('me/fcm-token')
    @ApiOperation({ summary: 'FCM 토큰 등록/갱신 (본인)' })
    @ApiBody({
        schema: {
            type: 'object',
            properties: {
                device_token: { type: 'string' },
                platform: { type: 'string' },
                device_id: { type: 'string' },
                device_model: { type: 'string' },
                os_version: { type: 'string' },
                app_version: { type: 'string' },
            },
            required: ['device_token', 'platform']
        }
    })
    async updateMyFcmToken(
        @CurrentUser() userId: string,
        @Body() body: { device_token: string; platform: string; device_id?: string; device_model?: string; os_version?: string; app_version?: string },
    ) {
        if (!body.device_token || !body.platform) {
            throw new BadRequestException('device_token and platform are required');
        }

        const result = await this.usersService.registerOrUpdateFcmToken(userId, body);
        return {
            success: true,
            data: result
        };
    }

    @Delete('me/fcm-token/:tokenId')
    @ApiOperation({ summary: 'FCM 토큰 비활성화 (본인)' })
    async deleteMyFcmToken(
        @CurrentUser() userId: string,
        @Param('tokenId') tokenId: string
    ) {
        await this.usersService.deactivateFcmToken(userId, tokenId);
        return {
            success: true,
            data: { message: 'FCM token deleted successfully' }
        };
    }

    @Public()
    @Get(':userId')
    @ApiOperation({ summary: '특정 사용자 조회 (userId)' })
    async getUserById(
        @Param('userId') paramUserId: string
    ) {
        if (paramUserId === 'me') {
            throw new UnauthorizedException('Use /api/v1/users/me with authentication');
        }

        const user = await this.usersService.getProfile(paramUserId);
        return {
            success: true,
            data: user
        };
    }

    @Public()
    @Put(':userId')
    @ApiOperation({ summary: '테스트용 특정 사용자 프로필 수정' })
    @ApiBody({
        schema: {
            type: 'object',
            properties: {
                display_name: { type: 'string' },
                profile_image_url: { type: 'string' },
                date_of_birth: { type: 'string' },
            },
            required: ['display_name']
        }
    })
    async updateTestUser(
        @Param('userId') paramUserId: string,
        @Body() body: { display_name: string; profile_image_url?: string; date_of_birth?: string }
    ) {
        if (!body.display_name) throw new BadRequestException('display_name is required');

        const updateData: any = { displayName: body.display_name };
        if (body.profile_image_url !== undefined && body.profile_image_url !== "") updateData.profileImageUrl = body.profile_image_url;
        else if (body.profile_image_url === "" || body.profile_image_url === null) updateData.profileImageUrl = null;

        if (body.date_of_birth !== undefined && body.date_of_birth !== "") updateData.dateOfBirth = body.date_of_birth;
        else if (body.date_of_birth === "" || body.date_of_birth === null) updateData.dateOfBirth = null;

        const updatedUser = await this.usersService.updateProfile(paramUserId, updateData);
        return {
            success: true,
            data: updatedUser
        };
    }

    @Public()
    @Put(':userId/fcm-token')
    @ApiOperation({ summary: '테스트용 특정 사용자 FCM 토큰 등록/갱신' })
    @ApiBody({
        schema: {
            type: 'object',
            properties: {
                device_token: { type: 'string' },
                platform: { type: 'string' },
                device_id: { type: 'string' },
                device_model: { type: 'string' },
                os_version: { type: 'string' },
                app_version: { type: 'string' },
            },
            required: ['device_token', 'platform']
        }
    })
    async updateTestFcmToken(
        @Param('userId') paramUserId: string,
        @Body() body: { device_token: string; platform: string; device_id?: string; device_model?: string; os_version?: string; app_version?: string },
    ) {
        if (!body.device_token || !body.platform) {
            throw new BadRequestException('device_token and platform are required');
        }

        const result = await this.usersService.registerOrUpdateFcmToken(paramUserId, body);
        return {
            success: true,
            data: result
        };
    }

    @Patch(':id/terms')
    @ApiOperation({ summary: '약관 동의 기록' })
    @ApiBody({
        schema: {
            type: 'object',
            properties: {
                terms_version: { type: 'string' }
            },
            required: ['terms_version']
        }
    })
    async agreeToTerms(
        @CurrentUser() currentUserId: string,
        @Param('id') id: string,
        @Body() body: { terms_version: string }
    ) {
        if (!body.terms_version) throw new BadRequestException('terms_version is required');
        if (currentUserId !== id) throw new ForbiddenException('id does not match authenticated user');

        const result = await this.usersService.agreeToTerms(id, body.terms_version);
        return {
            success: true,
            data: {
                terms_agreed_at: result.termsAgreedAt
            }
        };
    }
}
