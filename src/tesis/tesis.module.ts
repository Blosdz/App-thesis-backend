import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PlanesModule } from '../planes/planes.module';
import { TesisController } from './tesis.controller';
import { TesisService } from './tesis.service';

@Module({
  imports: [DatabaseModule, PlanesModule, NotificationsModule],
  controllers: [TesisController],
  providers: [TesisService],
})
export class TesisModule {}
