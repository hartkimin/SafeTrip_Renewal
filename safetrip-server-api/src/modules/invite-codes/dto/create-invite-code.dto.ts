import { IsString, IsOptional, IsInt, IsIn, Min } from 'class-validator';

export class CreateInviteCodeDto {
    @IsString()
    @IsIn(['crew_chief', 'crew', 'guardian'])
    target_role: string;

    @IsOptional()
    @IsInt()
    @Min(1)
    max_uses?: number;

    @IsOptional()
    @IsInt()
    @Min(1)
    expires_hours?: number;
}
