import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import {
  BeneficiosController,
  SuscripcionesController,
} from './suscripciones.controller';
import { SuscripcionesService } from './suscripciones.service';

@Module({
  imports: [DatabaseModule],
  controllers: [SuscripcionesController, BeneficiosController],
  providers: [SuscripcionesService],
})
export class SuscripcionesModule {}
