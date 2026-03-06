import { IsString, IsOptional, IsIn } from 'class-validator';
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

    @Expose({ name: 'avatar_id' })
    @IsString()
    @IsOptional()
    avatarId?: string;

    @Expose({ name: 'privacy_level' })
    @IsIn(['safety_first', 'standard', 'privacy_first'])
    @IsOptional()
    privacyLevel?: string;
}
