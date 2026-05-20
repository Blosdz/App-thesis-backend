import { Module } from '@nestjs/common';
import { DeepseekService } from './deepseek.service';
import { DeepseekController } from './deepseek.controller';
import { DatabaseModule } from '../database/database.module';
import { DocumentosModule } from '../documentos/documentos.module';

@Module({
  imports: [DatabaseModule, DocumentosModule],
  providers: [DeepseekService],
  controllers: [DeepseekController],
  exports: [DeepseekService],
})
export class DeepseekModule {}
