import { IsString, IsOptional, IsNotEmpty } from 'class-validator';
import { Expose } from 'class-transformer';

export class RegisterTestUserDto {
    @Expose({ name: 'user_id' })
    @IsNotEmpty()
    @IsString()
    userId: string;

    @Expose({ name: 'display_name' })
    @IsString()
    @IsOptional()
    displayName?: string;

    @Expose({ name: 'phone_number' })
    @IsString()
    @IsOptional()
    phoneNumber?: string;

    @Expose({ name: 'phone_country_code' })
    @IsString()
    @IsOptional()
    phoneCountryCode?: string;
}
