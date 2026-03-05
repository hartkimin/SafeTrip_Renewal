import { IsString, IsOptional, IsNotEmpty } from 'class-validator';
import { Expose } from 'class-transformer';

export class UpdateFcmTokenDto {
    @Expose({ name: 'device_token' })
    @IsNotEmpty()
    @IsString()
    deviceToken: string;

    @Expose({ name: 'platform' })
    @IsNotEmpty()
    @IsString()
    platform: string;

    @Expose({ name: 'device_id' })
    @IsString()
    @IsOptional()
    deviceId?: string;

    @Expose({ name: 'device_model' })
    @IsString()
    @IsOptional()
    deviceModel?: string;

    @Expose({ name: 'os_version' })
    @IsString()
    @IsOptional()
    osVersion?: string;

    @Expose({ name: 'app_version' })
    @IsString()
    @IsOptional()
    appVersion?: string;
}
