import { Module } from '@nestjs/common';
import { GoogleModule } from '../google/google.module';
import { PagosController } from './pagos.controller';
import { PagosService } from './pagos.service';

@Module({
  imports: [GoogleModule],
  controllers: [PagosController],
  providers: [PagosService],
})
export class PagosModule {}
