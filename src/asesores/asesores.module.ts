import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import {
  AsesoresController,
  DisponibilidadController,
  RelacionesController,
} from './asesores.controller';
import { AsesoresService } from './asesores.service';

@Module({
  imports: [DatabaseModule],
  controllers: [
    AsesoresController,
    RelacionesController,
    DisponibilidadController,
  ],
  providers: [AsesoresService],
})
export class AsesoresModule {}
