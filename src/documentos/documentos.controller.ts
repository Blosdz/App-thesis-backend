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
import { ActualizarRevisionDocumentoDto } from './dto/actualizar-revision-documento.dto';
import { RegistrarDocumentoDto } from './dto/registrar-documento.dto';
import { DocumentosService } from './documentos.service';

@UseGuards(JwtAuthGuard)
@Controller('documentos')
export class DocumentosController {
  constructor(private readonly documentosService: DocumentosService) {}

  @Post('tesis')
  registrar(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: RegistrarDocumentoDto,
  ) {
    return this.documentosService.registrar(user, dto);
  }

  @Post('tesis/:tesisId/carpeta-drive')
  crearCarpetaDrive(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
  ) {
    return this.documentosService.crearCarpetaDrive(user, tesisId);
  }

  @Post('tesis/:tesisId/archivo')
  @UseInterceptors(FileInterceptor('file'))
  subirArchivo(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @UploadedFile() file: Express.Multer.File,
    @Body('modo') modo = 'tesis',
    @Body('tipo_documento') tipoDocumento?: string,
  ) {
    return this.documentosService.subirArchivo(user, tesisId, file, {
      modo,
      tipoDocumento,
    });
  }

  @Get('tesis/:tesisId')
  listarPorTesis(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
  ) {
    return this.documentosService.listarPorTesis(user, tesisId);
  }

  @Get('tesis/:tesisId/asignada')
  listarPorTesisAsignada(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
  ) {
    return this.documentosService.listarPorTesis(user, tesisId);
  }

  @Get('tesis/:tesisId/apoyo')
  listarApoyo(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
  ) {
    return this.documentosService.listarApoyo(user, tesisId);
  }

  @Patch(':documentoId/revision')
  actualizarRevision(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('documentoId') documentoId: string,
    @Body() dto: ActualizarRevisionDocumentoDto,
  ) {
    return this.documentosService.actualizarRevision(user, documentoId, dto);
  }
}
