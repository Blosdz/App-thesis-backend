import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { GoogleModule } from '../google/google.module';
import { DocumentosController } from './documentos.controller';
import { DocumentosService } from './documentos.service';

@Module({
  imports: [DatabaseModule, GoogleModule],
  controllers: [DocumentosController],
  providers: [DocumentosService],
  exports: [DocumentosService],
})
export class DocumentosModule {}
