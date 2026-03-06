import { IsString, IsOptional, IsInt, Min, Max } from 'class-validator';
import { Expose } from 'class-transformer';

export class CreateEmergencyContactDto {
    @Expose({ name: 'contact_name' })
    @IsString()
    contactName: string;

    @Expose({ name: 'phone_number' })
    @IsString()
    phoneNumber: string;

    @Expose({ name: 'phone_country_code' })
    @IsString()
    @IsOptional()
    phoneCountryCode?: string;

    @Expose({ name: 'relationship' })
    @IsString()
    @IsOptional()
    relationship?: string;

    @Expose({ name: 'contact_order' })
    @IsInt()
    @Min(1)
    @Max(2)
    @IsOptional()
    contactOrder?: number;
}

export class UpdateEmergencyContactDto {
    @Expose({ name: 'contact_name' })
    @IsString()
    @IsOptional()
    contactName?: string;

    @Expose({ name: 'phone_number' })
    @IsString()
    @IsOptional()
    phoneNumber?: string;

    @Expose({ name: 'phone_country_code' })
    @IsString()
    @IsOptional()
    phoneCountryCode?: string;

    @Expose({ name: 'relationship' })
    @IsString()
    @IsOptional()
    relationship?: string;
}
