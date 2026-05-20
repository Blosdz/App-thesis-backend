import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { NotificationsModule } from '../notifications/notifications.module';
import {
  AsesoresController,
  DisponibilidadController,
  RelacionesController,
} from './asesores.controller';
import { AsesoresService } from './asesores.service';

@Module({
  imports: [DatabaseModule, NotificationsModule],
  controllers: [
    AsesoresController,
    RelacionesController,
    DisponibilidadController,
  ],
  providers: [AsesoresService],
})
export class AsesoresModule {}
