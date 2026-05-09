import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { GoogleModule } from '../google/google.module';
import { ReunionesController } from './reuniones.controller';
import { ReunionesService } from './reuniones.service';

@Module({
  imports: [DatabaseModule, GoogleModule],
  controllers: [ReunionesController],
  providers: [ReunionesService],
})
export class ReunionesModule {}
