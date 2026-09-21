import { Body, Controller, Delete, Get, Param, ParseUUIDPipe, Patch, Post, Put, Query, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DocGeneratorService } from './doc-generator.service';

@UseGuards(JwtAuthGuard)
@Controller('tesis/:tesisId/bibliografia')
export class BibliographyController {
  constructor(private readonly service: DocGeneratorService) {}
  @Get('workspace') workspace(@Param('tesisId', ParseUUIDPipe) id: string, @Query('document_id') doc: string, @CurrentUserDecorator() user: CurrentUser) { return this.service.bibliography(id, 'workspace', user, 'GET', undefined, doc); }
  @Post('referencias') create(@Param('tesisId', ParseUUIDPipe) id: string, @Body() body: Record<string, unknown>, @CurrentUserDecorator() user: CurrentUser) { return this.service.bibliography(id, 'referencias', user, 'POST', body); }
  @Patch('referencias/:referenceId') update(@Param('tesisId', ParseUUIDPipe) id: string, @Param('referenceId', ParseUUIDPipe) ref: string, @Body() body: Record<string, unknown>, @CurrentUserDecorator() user: CurrentUser) { return this.service.bibliography(id, `referencias/${ref}`, user, 'PATCH', body); }
  @Delete('referencias/:referenceId') remove(@Param('tesisId', ParseUUIDPipe) id: string, @Param('referenceId', ParseUUIDPipe) ref: string, @CurrentUserDecorator() user: CurrentUser) { return this.service.bibliography(id, `referencias/${ref}`, user, 'DELETE'); }
  @Post('preview') preview(@Param('tesisId', ParseUUIDPipe) id: string, @Body() body: Record<string, unknown>, @CurrentUserDecorator() user: CurrentUser) { return this.service.bibliography(id, 'preview', user, 'POST', body); }
  @Post('resolver-doi') doi(@Param('tesisId', ParseUUIDPipe) id: string, @Body() body: Record<string, unknown>, @CurrentUserDecorator() user: CurrentUser) { return this.service.bibliography(id, 'resolver-doi', user, 'POST', body); }
  @Put('estilo') style(@Param('tesisId', ParseUUIDPipe) id: string, @Body() body: Record<string, unknown>, @CurrentUserDecorator() user: CurrentUser) { return this.service.bibliography(id, 'estilo', user, 'PUT', body); }
  @Post('documentos/:documentId/:action') document(@Param('tesisId', ParseUUIDPipe) id: string, @Param('documentId', ParseUUIDPipe) doc: string, @Param('action') action: string, @Body() body: Record<string, unknown>, @CurrentUserDecorator() user: CurrentUser) { return this.service.bibliography(id, `documentos/${doc}/${action}`, user, 'POST', body, doc); }
  @Post('exportaciones') export(@Param('tesisId', ParseUUIDPipe) id: string, @CurrentUserDecorator() user: CurrentUser) { return this.service.bibliography(id, 'exportaciones', user, 'POST'); }
  @Post('importaciones') @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 20 * 1024 * 1024 } })) upload(@Param('tesisId', ParseUUIDPipe) id: string, @UploadedFile() file: Express.Multer.File, @CurrentUserDecorator() user: CurrentUser) { return this.service.bibliographyUpload(id, file, user); }
  @Get('plantilla') template(@Param('tesisId', ParseUUIDPipe) id: string, @CurrentUserDecorator() user: CurrentUser) { return this.service.bibliography(id, 'plantilla', user, 'GET'); }
  @Get(':collection/:operationId/archivo') file(@Param('tesisId', ParseUUIDPipe) id: string, @Param('collection') collection: string, @Param('operationId', ParseUUIDPipe) operation: string, @CurrentUserDecorator() user: CurrentUser) { return this.service.bibliography(id, `${collection}/${operation}/archivo`, user, 'GET'); }
  @Get(':collection/:operationId') operation(@Param('tesisId', ParseUUIDPipe) id: string, @Param('collection') collection: string, @Param('operationId', ParseUUIDPipe) operation: string, @CurrentUserDecorator() user: CurrentUser) { return this.service.bibliography(id, `${collection}/${operation}`, user, 'GET'); }
}
