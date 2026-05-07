import { Module } from '@nestjs/common';
import { AsesoresController } from './asesores.controller';
import { AsesoresService } from './asesores.service';

@Module({
  controllers: [AsesoresController],
  providers: [AsesoresService],
})
export class AsesoresModule {}
