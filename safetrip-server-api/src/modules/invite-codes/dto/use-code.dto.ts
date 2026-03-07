import { IsString, IsNotEmpty } from 'class-validator';

export class UseCodeDto {
    @IsString()
    @IsNotEmpty()
    code: string;
}
