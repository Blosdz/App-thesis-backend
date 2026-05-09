import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { SugerenciasController } from './sugerencias.controller';
import { SugerenciasService } from './sugerencias.service';

@Module({
  imports: [DatabaseModule],
  controllers: [SugerenciasController],
  providers: [SugerenciasService],
})
export class SugerenciasModule {}
