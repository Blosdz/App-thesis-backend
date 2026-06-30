import {
  Body,
  Controller,
  Get,
  Headers,
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
import { ActualizarFormatoDocTesisDto } from './dto/actualizar-formato-doc-tesis.dto';
import { ActualizarEstadoTesisDto } from './dto/actualizar-estado-tesis.dto';
import { AsignarAsesorDto } from './dto/asignar-asesor.dto';
import { CrearTesisConPlanDto, CrearTesisDto } from './dto/crear-tesis.dto';
import { TesisService } from './tesis.service';

@UseGuards(JwtAuthGuard)
@Controller('tesis')
export class TesisController {
  constructor(private readonly tesisService: TesisService) {}

  @Post()
  crear(@CurrentUserDecorator() user: CurrentUser, @Body() dto: CrearTesisDto) {
    return this.tesisService.crear(user, dto);
  }

  @Post('con-plan')
  crearConPlan(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: CrearTesisConPlanDto,
  ) {
    return this.tesisService.crearConPlan(user, dto);
  }

  @Get('mis-tesis')
  misTesis(@CurrentUserDecorator() user: CurrentUser) {
    return this.tesisService.misTesis(user);
  }

  @Get('mis-tesis-con-asesores')
  misTesisConAsesores(@CurrentUserDecorator() user: CurrentUser) {
    return this.tesisService.misTesisConAsesores(user);
  }

  @Get('asignadas-asesor')
  asignadasAsesor(@CurrentUserDecorator() user: CurrentUser) {
    return this.tesisService.asignadasAsesor(user);
  }

  @Get(':tesisId')
  obtenerDetalle(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
  ) {
    return this.tesisService.obtenerDetalle(user, tesisId);
  }

  @Patch(':tesisId/estado')
  actualizarEstado(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @Body() dto: ActualizarEstadoTesisDto,
  ) {
    return this.tesisService.actualizarEstado(user, tesisId, dto);
  }

  @Patch(':tesisId/formato-doc')
  actualizarFormatoDoc(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @Body() dto: ActualizarFormatoDocTesisDto,
  ) {
    return this.tesisService.actualizarFormatoDoc(user, tesisId, dto);
  }

  @Post(':tesisId/asignar-asesor')
  asignarAsesor(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @Body() dto: AsignarAsesorDto,
  ) {
    return this.tesisService.asignarAsesor(user, tesisId, dto);
  }

  @Post(':tesisId/caratula')
  @UseInterceptors(FileInterceptor('file'))
  subirCaratula(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.tesisService.subirCaratula(user, tesisId, file);
  }

  @Post(':tesisId/documentos/docx')
  generarDocumentoDocx(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @Headers('authorization') authorization?: string,
  ) {
    return this.tesisService.generarDocumentoDocx(user, tesisId, authorization);
  }
}
