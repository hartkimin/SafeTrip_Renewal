import { IsString, IsOptional } from 'class-validator';
import { Expose } from 'class-transformer';

export class UpdateProfileDto {
    @Expose({ name: 'display_name' })
    @IsString()
    @IsOptional()
    displayName?: string;

    @Expose({ name: 'profile_image_url' })
    @IsString()
    @IsOptional()
    profileImageUrl?: string;

    @Expose({ name: 'date_of_birth' })
    @IsString()
    @IsOptional()
    dateOfBirth?: string;

    @Expose({ name: 'location_sharing_mode' })
    @IsString()
    @IsOptional()
    locationSharingMode?: string;
}
