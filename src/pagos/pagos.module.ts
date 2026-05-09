import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { GoogleModule } from '../google/google.module';
import { PlanesModule } from '../planes/planes.module';
import { PagosController } from './pagos.controller';
import { PagosService } from './pagos.service';

@Module({
  imports: [DatabaseModule, PlanesModule, GoogleModule],
  controllers: [PagosController],
  providers: [PagosService],
  exports: [PagosService],
})
export class PagosModule {}
