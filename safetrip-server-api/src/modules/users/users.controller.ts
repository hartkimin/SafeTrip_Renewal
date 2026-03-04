import { Controller, Get, Patch, Post, Put, Delete, Body, Param, Query, HttpCode, HttpStatus, UnauthorizedException, BadRequestException, NotFoundException, ForbiddenException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiBody, ApiQuery } from '@nestjs/swagger';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Public } from '../../common/decorators/public.decorator';
import { UsersService } from './users.service';
import { RegisterTestUserDto } from './dto/register-user.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { UpdateFcmTokenDto } from './dto/update-fcm-token.dto';

@ApiTags('Users')
@ApiBearerAuth('firebase-auth')
@Controller('users')
export class UsersController {
    constructor(private readonly usersService: UsersService) { }

    @Public()
    @Post('register')
    @HttpCode(HttpStatus.CREATED)
    @ApiOperation({ summary: '테스트용 사용자 등록' })
    async registerTestUser(@Body() body: RegisterTestUserDto) {
        // ValidationPipe handles IsNotEmpty for userId
        const user = await this.usersService.registerTestUser({
            user_id: body.userId,
            display_name: body.displayName,
            phone_number: body.phoneNumber,
            phone_country_code: body.phoneCountryCode
        });
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
        @Body() body: UpdateProfileDto,
    ) {
        const updateData: any = {};
        if (body.displayName !== undefined) updateData.displayName = body.displayName;
        if (body.profileImageUrl !== undefined) updateData.profileImageUrl = body.profileImageUrl;
        if (body.dateOfBirth !== undefined) updateData.dateOfBirth = body.dateOfBirth;
        if (body.locationSharingMode !== undefined) updateData.locationSharingMode = body.locationSharingMode;

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
    async updateMyFcmToken(
        @CurrentUser() userId: string,
        @Body() body: UpdateFcmTokenDto,
    ) {
        const result = await this.usersService.registerOrUpdateFcmToken(userId, {
            device_token: body.deviceToken,
            platform: body.platform,
            device_id: body.deviceId,
            device_model: body.deviceModel,
            os_version: body.osVersion,
            app_version: body.appVersion
        });
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
    async updateTestUser(
        @Param('userId') paramUserId: string,
        @Body() body: UpdateProfileDto
    ) {
        if (!body.displayName) throw new BadRequestException('display_name is required');

        const updateData: any = { displayName: body.displayName };
        if (body.profileImageUrl !== undefined && body.profileImageUrl !== "") updateData.profileImageUrl = body.profileImageUrl;
        else if (body.profileImageUrl === "" || body.profileImageUrl === null) updateData.profileImageUrl = null;

        if (body.dateOfBirth !== undefined && body.dateOfBirth !== "") updateData.dateOfBirth = body.dateOfBirth;
        else if (body.dateOfBirth === "" || body.dateOfBirth === null) updateData.dateOfBirth = null;

        const updatedUser = await this.usersService.updateProfile(paramUserId, updateData);
        return {
            success: true,
            data: updatedUser
        };
    }

    @Public()
    @Put(':userId/fcm-token')
    @ApiOperation({ summary: '테스트용 특정 사용자 FCM 토큰 등록/갱신' })
    async updateTestFcmToken(
        @Param('userId') paramUserId: string,
        @Body() body: UpdateFcmTokenDto,
    ) {
        const result = await this.usersService.registerOrUpdateFcmToken(paramUserId, {
            device_token: body.deviceToken,
            platform: body.platform,
            device_id: body.deviceId,
            device_model: body.deviceModel,
            os_version: body.osVersion,
            app_version: body.appVersion
        });
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
