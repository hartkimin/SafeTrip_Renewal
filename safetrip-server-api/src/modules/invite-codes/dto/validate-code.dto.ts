import { IsString, IsNotEmpty } from 'class-validator';

export class ValidateCodeDto {
    @IsString()
    @IsNotEmpty()
    code: string;
}
