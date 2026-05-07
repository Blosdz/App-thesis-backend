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
import { CrearSugerenciaDto } from './dto/crear-sugerencia.dto';
import { MarcarSugerenciaDto } from './dto/marcar-sugerencia.dto';
import { ValidarSugerenciaDto } from './dto/validar-sugerencia.dto';
import { SugerenciasService } from './sugerencias.service';

@Controller('sugerencias')
@UseGuards(JwtAuthGuard)
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
  listar(@Param('tesisId') tesisId: string) {
    return this.sugerenciasService.listar(tesisId);
  }

  @Patch(':id/aplicada')
  marcar(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('id') sugerenciaId: string,
    @Body() dto: MarcarSugerenciaDto,
  ) {
    return this.sugerenciasService.marcar(user, sugerenciaId, dto);
  }

  @Patch(':id/validar')
  validar(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('id') historialSugerenciaId: string,
    @Body() dto: ValidarSugerenciaDto,
  ) {
    return this.sugerenciasService.validar(user, historialSugerenciaId, dto);
  }
}
