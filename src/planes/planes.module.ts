import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PlanesController } from './planes.controller';
import { PlanesService } from './planes.service';

@Module({
  imports: [DatabaseModule, NotificationsModule],
  controllers: [PlanesController],
  providers: [PlanesService],
  exports: [PlanesService],
})
export class PlanesModule {}
