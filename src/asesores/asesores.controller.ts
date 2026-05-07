import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { AsignarTesisAsesorDto } from './dto/asignar-tesis-asesor.dto';
import { BloquesDisponiblesDto } from './dto/bloques-disponibles.dto';
import { CambiarEstadoRelacionDto } from './dto/cambiar-estado-relacion.dto';
import { CrearEspacioLibreDto } from './dto/crear-espacio-libre.dto';
import { VincularAsesorDto } from './dto/vincular-asesor.dto';
import { AsesoresService } from './asesores.service';

@Controller('asesores')
export class AsesoresController {
  constructor(private readonly asesoresService: AsesoresService) {}

  @Get()
  listar() {
    return this.asesoresService.listar();
  }

  @Post('vincular/slug')
  @UseGuards(JwtAuthGuard)
  vincularPorSlug(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: VincularAsesorDto,
  ) {
    return this.asesoresService.vincularPorSlug(user, dto);
  }

  @Post('vincular/codigo')
  @UseGuards(JwtAuthGuard)
  vincularPorCodigo(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: VincularAsesorDto,
  ) {
    return this.asesoresService.vincularPorCodigo(user, dto);
  }

  @Post('codigo-publico')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('asesor')
  generarCodigo(@CurrentUserDecorator() user: CurrentUser) {
    return this.asesoresService.generarCodigo(user);
  }

  @Get('codigo-publico/me')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('asesor')
  obtenerCodigo(@CurrentUserDecorator() user: CurrentUser) {
    return this.asesoresService.obtenerCodigo(user);
  }

  @Get('mis-asesores')
  @UseGuards(JwtAuthGuard)
  misAsesores(@CurrentUserDecorator() user: CurrentUser) {
    return this.asesoresService.misAsesores(user);
  }

  @Get('mis-estudiantes')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('asesor')
  misEstudiantes(@CurrentUserDecorator() user: CurrentUser) {
    return this.asesoresService.misEstudiantes(user);
  }

  @Patch('relaciones/:id/estado')
  @UseGuards(JwtAuthGuard)
  cambiarEstadoRelacion(
    @Param('id') relacionId: string,
    @Body() dto: CambiarEstadoRelacionDto,
  ) {
    return this.asesoresService.cambiarEstadoRelacion(relacionId, dto);
  }

  @Post('tesis/asignar')
  @UseGuards(JwtAuthGuard)
  asignarTesis(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: AsignarTesisAsesorDto,
  ) {
    return this.asesoresService.asignarTesis(user, dto);
  }

  @Post('agenda/espacios-libres')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('asesor')
  crearEspacioLibre(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: CrearEspacioLibreDto,
  ) {
    return this.asesoresService.crearEspacioLibre(user, dto);
  }

  @Get('agenda/espacios-libres')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('asesor')
  listarEspaciosLibres(@CurrentUserDecorator() user: CurrentUser) {
    return this.asesoresService.listarEspaciosLibres(user);
  }

  @Delete('agenda/espacios-libres/:id')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('asesor')
  desactivarEspacioLibre(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('id') disponibilidadId: string,
  ) {
    return this.asesoresService.desactivarEspacioLibre(user, disponibilidadId);
  }

  @Get('agenda/bloques-disponibles')
  bloquesDisponibles(@Query() query: BloquesDisponiblesDto) {
    return this.asesoresService.bloquesDisponibles(query);
  }
}
