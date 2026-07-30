import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  Param,
  Patch,
  Post,
  Put,
  UseGuards,
} from '@nestjs/common';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DocGeneratorService } from './doc-generator.service';

@UseGuards(JwtAuthGuard)
@Controller('ai/tesis')
export class AiThesisDocController {
  constructor(private readonly docGeneratorService: DocGeneratorService) {}

  @Get(':tesisId')
  getThesis(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
  ) {
    return this.docGeneratorService.getThesis(tesisId, user);
  }

  @Get(':tesisId/referencias')
  listReferences(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
  ) {
    return this.docGeneratorService.listReferences(tesisId, user);
  }

  @Post(':tesisId/referencias')
  createReference(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.docGeneratorService.createReference(tesisId, body, user);
  }

  @Patch('referencias/:referenceId')
  updateReference(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('referenceId') referenceId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.docGeneratorService.updateReference(referenceId, body, user);
  }

  @Delete('referencias/:referenceId')
  deleteReference(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('referenceId') referenceId: string,
  ) {
    return this.docGeneratorService.deleteReference(referenceId, user);
  }

  @Get(':tesisId/indice')
  listIndex(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
  ) {
    return this.docGeneratorService.listIndex(tesisId, user);
  }

  @Post(':tesisId/indice')
  createIndexSection(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.docGeneratorService.createIndexSection(tesisId, body, user);
  }

  @Put(':tesisId/indice')
  replaceIndex(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @Body() body: Array<Record<string, unknown>>,
  ) {
    return this.docGeneratorService.replaceIndex(tesisId, body, user);
  }

  @Patch(':tesisId/indice/:sectionId')
  updateIndexSection(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @Param('sectionId') sectionId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.docGeneratorService.updateIndexSection(
      tesisId,
      sectionId,
      body,
      user,
    );
  }

  @Post(':tesisId/indice/:sectionId/texto')
  appendIndexSectionText(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @Param('sectionId') sectionId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.docGeneratorService.appendIndexSectionText(
      tesisId,
      sectionId,
      body,
      user,
    );
  }

  @Delete(':tesisId/indice/:sectionId')
  deleteIndexSection(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @Param('sectionId') sectionId: string,
  ) {
    return this.docGeneratorService.deleteIndexSection(tesisId, sectionId, user);
  }

  @Get('documentos/:documentoId/raw-data')
  getRawData(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
  ) {
    return this.docGeneratorService.getRawData(documentoId, user);
  }

  @Get('documentos/:documentoId/metadata-harness')
  getMetadataHarness(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
  ) {
    return this.docGeneratorService.getMetadataHarness(documentoId, user);
  }

  @Get('documentos/:documentoId/raw-document')
  getRawDocument(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
  ) {
    return this.docGeneratorService.getRawDocument(documentoId, user);
  }

  @Patch('documentos/:documentoId/raw-data')
  updateRawData(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.docGeneratorService.updateRawData(documentoId, body, user);
  }

  @Post('documentos/:documentoId/raw-data/extract')
  extractRawData(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
  ) {
    return this.docGeneratorService.extractRawData(documentoId, user);
  }

  @Post('documentos/:documentoId/process')
  processDocument(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
  ) {
    return this.docGeneratorService.processDocument(documentoId, user);
  }

  @Post('documentos/:documentoId/outline/extract')
  extractOutline(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
  ) {
    return this.docGeneratorService.extractOutline(documentoId, user);
  }

  @Post('documentos/:documentoId/references/extract-section')
  extractSectionReferences(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.docGeneratorService.extractSectionReferences(
      documentoId,
      body,
      user,
    );
  }

  @Get('documentos/:documentoId/sections')
  listSections(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
  ) {
    return this.docGeneratorService.listSections(documentoId, user);
  }

  @Get('documentos/:documentoId/sections/:sectionId')
  getSection(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
    @Param('sectionId') sectionId: string,
  ) {
    return this.docGeneratorService.getSection(documentoId, sectionId, user);
  }

  @Patch('documentos/:documentoId/sections/:sectionId')
  updateSection(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
    @Param('sectionId') sectionId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.docGeneratorService.updateSection(
      documentoId,
      sectionId,
      body,
      user,
    );
  }

  @Get('documentos/:documentoId/references')
  listDocumentReferences(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
  ) {
    return this.docGeneratorService.listDocumentReferences(documentoId, user);
  }

  @Get('documentos/:documentoId/references/:referenceId')
  getDocumentReference(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
    @Param('referenceId') referenceId: string,
  ) {
    return this.docGeneratorService.getDocumentReference(
      documentoId,
      referenceId,
      user,
    );
  }

  @Patch('documentos/:documentoId/references/:referenceId')
  updateDocumentReference(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
    @Param('referenceId') referenceId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.docGeneratorService.updateDocumentReference(
      documentoId,
      referenceId,
      body,
      user,
    );
  }

  @Get('documentos/:documentoId/preview')
  getPreview(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
  ) {
    return this.docGeneratorService.getPreview(documentoId, user);
  }

  @Post('documentos/:documentoId/citations')
  insertCitation(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.docGeneratorService.insertCitation(documentoId, body, user);
  }

  @Post('documentos/:documentoId/headings')
  insertHeading(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.docGeneratorService.insertHeading(documentoId, body, user);
  }

  @Post('documentos/:documentoId/subtitles')
  insertSubtitle(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.docGeneratorService.insertSubtitle(documentoId, body, user);
  }

  @Post(':tesisId/documentos/docx')
  generateDocx(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @Headers('authorization') authorization?: string,
  ) {
    return this.docGeneratorService.generateDocx(
      tesisId,
      { uploadToBackend: true, authorization },
      user,
    );
  }

  @Get('documentos/:documentoId/download')
  downloadEditableDocument(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
  ) {
    return this.docGeneratorService.downloadEditableDocument(documentoId, user);
  }

  @Get('documentos/:filename')
  downloadDocument(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('filename') filename: string,
  ) {
    return this.docGeneratorService.downloadDocument(filename, user);
  }
}
