import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { ObservacionesController } from './observaciones.controller';
import { ObservacionesService } from './observaciones.service';

@Module({
  imports: [DatabaseModule],
  controllers: [ObservacionesController],
  providers: [ObservacionesService],
})
export class ObservacionesModule {}
