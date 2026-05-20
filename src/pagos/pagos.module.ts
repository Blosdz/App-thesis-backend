import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { EmailModule } from '../email/email.module';
import { GoogleModule } from '../google/google.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PlanesModule } from '../planes/planes.module';
import { CursosModule } from '../cursos/cursos.module';
import { PagosController } from './pagos.controller';
import { PagosService } from './pagos.service';

@Module({
  imports: [
    DatabaseModule,
    PlanesModule,
    GoogleModule,
    NotificationsModule,
    CursosModule,
    EmailModule,
  ],
  controllers: [PagosController],
  providers: [PagosService],
  exports: [PagosService],
})
export class PagosModule {}
