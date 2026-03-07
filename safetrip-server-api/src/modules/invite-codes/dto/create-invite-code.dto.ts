import { IsString, IsOptional, IsInt, IsIn, Min, Max } from 'class-validator';

export class CreateInviteCodeDto {
    @IsString()
    @IsIn(['crew_chief', 'crew', 'guardian'])
    target_role: string;

    @IsOptional()
    @IsInt()
    @Min(1)
    @Max(100)  // §03.3: 다중 사용 최대 100
    max_uses?: number;

    @IsOptional()
    @IsInt()
    @Min(1)
    @Max(168)  // §03.2: 최대 7일(168시간)
    expires_hours?: number;
}
