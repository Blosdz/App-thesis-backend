import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { GoogleModule } from '../google/google.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { CursosController } from './cursos.controller';
import { CursosService } from './cursos.service';

@Module({
  imports: [DatabaseModule, GoogleModule, NotificationsModule],
  controllers: [CursosController],
  providers: [CursosService],
  exports: [CursosService],
})
export class CursosModule {}
