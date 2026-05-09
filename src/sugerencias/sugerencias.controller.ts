import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { ActualizarEstadoSugerenciaDto } from './dto/actualizar-estado-sugerencia.dto';
import { CrearSugerenciaDto } from './dto/crear-sugerencia.dto';
import { MarcarSugerenciaDto } from './dto/marcar-sugerencia.dto';
import { SugerenciasService } from './sugerencias.service';

@UseGuards(JwtAuthGuard)
@Controller('sugerencias')
export class SugerenciasController {
  constructor(private readonly sugerenciasService: SugerenciasService) {}

  @Post()
  crear(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: CrearSugerenciaDto,
  ) {
    return this.sugerenciasService.crear(user, dto);
  }

  @Get('tesis/:tesisId')
  listarPorTesis(@Param('tesisId') tesisId: string) {
    return this.sugerenciasService.listarPorTesis(tesisId);
  }

  @Get('tesis/:tesisId/validacion')
  listarValidacion(@Param('tesisId') tesisId: string) {
    return this.sugerenciasService.listarPorTesis(tesisId);
  }

  @Get('tipos')
  tipos() {
    return this.sugerenciasService.tipos();
  }

  @Patch(':sugerenciaId/aplicada')
  marcarAplicada(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('sugerenciaId') sugerenciaId: string,
    @Body() dto: MarcarSugerenciaDto,
  ) {
    return this.sugerenciasService.marcarAplicada(user, sugerenciaId, dto);
  }

  @Patch(':sugerenciaId/estado')
  actualizarEstado(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('sugerenciaId') sugerenciaId: string,
    @Body() dto: ActualizarEstadoSugerenciaDto,
  ) {
    return this.sugerenciasService.actualizarEstado(user, sugerenciaId, dto);
  }

  @Get(':sugerenciaId/log')
  log(@Param('sugerenciaId') sugerenciaId: string) {
    return this.sugerenciasService.log(sugerenciaId);
  }
}
