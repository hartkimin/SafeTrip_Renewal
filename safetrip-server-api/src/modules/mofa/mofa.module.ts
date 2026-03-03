import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { MofaController } from './mofa.controller';
import { MofaService } from './mofa.service';

@Module({
    imports: [HttpModule],
    controllers: [MofaController],
    providers: [MofaService],
    exports: [MofaService],
})
export class MofaModule { }
