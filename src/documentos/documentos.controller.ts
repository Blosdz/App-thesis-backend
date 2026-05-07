import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DocumentosService } from './documentos.service';
import { ActualizarRevisionDocumentoDto } from './dto/actualizar-revision-documento.dto';
import { RegistrarDocumentoDto } from './dto/registrar-documento.dto';
import { UploadDocumentoDto } from './dto/upload-documento.dto';

@Controller('documentos')
@UseGuards(JwtAuthGuard)
export class DocumentosController {
  constructor(private readonly documentosService: DocumentosService) {}

  @Get('tesis/:tesisId')
  listarPorTesis(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
  ) {
    return this.documentosService.listarPorTesis(user, tesisId);
  }

  @Post()
  registrar(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: RegistrarDocumentoDto,
  ) {
    return this.documentosService.registrar(user, dto);
  }

  @Post('upload')
  @UseInterceptors(FileInterceptor('file'))
  upload(
    @CurrentUserDecorator() user: CurrentUser,
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: UploadDocumentoDto,
  ) {
    return this.documentosService.upload(user, file, dto);
  }

  @Patch(':id/revision')
  actualizarRevision(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('id') documentoId: string,
    @Body() dto: ActualizarRevisionDocumentoDto,
  ) {
    return this.documentosService.actualizarRevision(user, documentoId, dto);
  }
}
