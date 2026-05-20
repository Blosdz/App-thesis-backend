import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { StorageModule } from '../storage/storage.module';
import { CursosController } from './cursos.controller';
import { CursosService } from './cursos.service';

@Module({
  imports: [DatabaseModule, NotificationsModule, StorageModule],
  controllers: [CursosController],
  providers: [CursosService],
  exports: [CursosService],
})
export class CursosModule {}
