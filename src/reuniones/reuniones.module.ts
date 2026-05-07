import { Module } from '@nestjs/common';
import { GoogleModule } from '../google/google.module';
import { ReunionesController } from './reuniones.controller';
import { ReunionesService } from './reuniones.service';

@Module({
  imports: [GoogleModule],
  controllers: [ReunionesController],
  providers: [ReunionesService],
})
export class ReunionesModule {}
