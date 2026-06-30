import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { AiThesisDocController } from './ai-thesis-doc.controller';
import { DocGeneratorService } from './doc-generator.service';

@Module({
  imports: [DatabaseModule],
  controllers: [AiThesisDocController],
  providers: [DocGeneratorService],
  exports: [DocGeneratorService],
})
export class DocGeneratorModule {}
