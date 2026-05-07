import { Module } from '@nestjs/common';
import { TesisController } from './tesis.controller';
import { TesisService } from './tesis.service';

@Module({
  controllers: [TesisController],
  providers: [TesisService],
})
export class TesisModule {}
