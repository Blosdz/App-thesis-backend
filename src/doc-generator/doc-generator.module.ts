import { Module } from '@nestjs/common';
import { AiThesisDocController } from './ai-thesis-doc.controller';
import { DocGeneratorService } from './doc-generator.service';

@Module({
  controllers: [AiThesisDocController],
  providers: [DocGeneratorService],
  exports: [DocGeneratorService],
})
export class DocGeneratorModule {}
