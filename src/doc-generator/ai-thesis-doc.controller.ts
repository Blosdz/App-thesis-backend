import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Put,
} from '@nestjs/common';
import { DocGeneratorService } from './doc-generator.service';

@Controller('ai/tesis')
export class AiThesisDocController {
  constructor(private readonly docGeneratorService: DocGeneratorService) {}

  @Get(':tesisId')
  getThesis(@Param('tesisId') tesisId: string) {
    return this.docGeneratorService.getThesis(tesisId);
  }

  @Get(':tesisId/referencias')
  listReferences(@Param('tesisId') tesisId: string) {
    return this.docGeneratorService.listReferences(tesisId);
  }

  @Post(':tesisId/referencias')
  createReference(
    @Param('tesisId') tesisId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.docGeneratorService.createReference(tesisId, body);
  }

  @Patch('referencias/:referenceId')
  updateReference(
    @Param('referenceId') referenceId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.docGeneratorService.updateReference(referenceId, body);
  }

  @Delete('referencias/:referenceId')
  deleteReference(@Param('referenceId') referenceId: string) {
    return this.docGeneratorService.deleteReference(referenceId);
  }

  @Get(':tesisId/indice')
  listIndex(@Param('tesisId') tesisId: string) {
    return this.docGeneratorService.listIndex(tesisId);
  }

  @Post(':tesisId/indice')
  createIndexSection(
    @Param('tesisId') tesisId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.docGeneratorService.createIndexSection(tesisId, body);
  }

  @Put(':tesisId/indice')
  replaceIndex(
    @Param('tesisId') tesisId: string,
    @Body() body: Array<Record<string, unknown>>,
  ) {
    return this.docGeneratorService.replaceIndex(tesisId, body);
  }

  @Patch(':tesisId/indice/:sectionId')
  updateIndexSection(
    @Param('tesisId') tesisId: string,
    @Param('sectionId') sectionId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.docGeneratorService.updateIndexSection(tesisId, sectionId, body);
  }

  @Delete(':tesisId/indice/:sectionId')
  deleteIndexSection(
    @Param('tesisId') tesisId: string,
    @Param('sectionId') sectionId: string,
  ) {
    return this.docGeneratorService.deleteIndexSection(tesisId, sectionId);
  }

  @Post(':tesisId/documentos/docx')
  generateDocx(@Param('tesisId') tesisId: string) {
    return this.docGeneratorService.generateDocx(tesisId);
  }

  @Get('documentos/:filename')
  downloadDocument(@Param('filename') filename: string) {
    return this.docGeneratorService.downloadDocument(filename);
  }
}
