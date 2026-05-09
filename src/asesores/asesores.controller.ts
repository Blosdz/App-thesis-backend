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
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { AsesoresService } from './asesores.service';
import { BloquesDisponiblesDto } from './dto/bloques-disponibles.dto';
import { CambiarEstadoRelacionDto } from './dto/cambiar-estado-relacion.dto';
import { CrearEspacioLibreDto } from './dto/crear-espacio-libre.dto';
import { VincularAsesorDto } from './dto/vincular-asesor.dto';

@Controller('asesores')
export class AsesoresController {
  constructor(private readonly asesoresService: AsesoresService) {}

  @Get()
  obtenerAsesores() {
    return this.asesoresService.obtenerAsesores();
  }

  @UseGuards(JwtAuthGuard)
  @Get('mis-asesores')
  obtenerMisAsesores(@CurrentUserDecorator() user: CurrentUser) {
    return this.asesoresService.obtenerMisAsesores(user);
  }

  @UseGuards(JwtAuthGuard)
  @Get('estudiantes')
  obtenerEstudiantesAsesor(@CurrentUserDecorator() user: CurrentUser) {
    return this.asesoresService.obtenerEstudiantesAsesor(user);
  }

  @UseGuards(JwtAuthGuard)
  @Post('codigo-publico')
  generarCodigoPublico(@CurrentUserDecorator() user: CurrentUser) {
    return this.asesoresService.generarCodigoPublico(user);
  }

  @UseGuards(JwtAuthGuard)
  @Get('mi-codigo-publico')
  obtenerMiCodigoPublico(@CurrentUserDecorator() user: CurrentUser) {
    return this.asesoresService.obtenerMiCodigoPublico(user);
  }

  @Get(':asesorId/perfil-publico')
  obtenerPerfilPublico(@Param('asesorId') asesorId: string) {
    return this.asesoresService.obtenerPerfilPublico(asesorId);
  }
}

@UseGuards(JwtAuthGuard)
@Controller('relaciones')
export class RelacionesController {
  constructor(private readonly asesoresService: AsesoresService) {}

  @Patch(':relacionId/estado')
  cambiarEstadoRelacion(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('relacionId') relacionId: string,
    @Body() dto: CambiarEstadoRelacionDto,
  ) {
    return this.asesoresService.cambiarEstadoRelacion(user, relacionId, dto);
  }

  @Post('asesor/slug/:slug')
  vincularPorSlug(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('slug') slug: string,
    @Body() dto: VincularAsesorDto,
  ) {
    return this.asesoresService.vincularPorSlug(user, slug, dto);
  }

  @Post('asesor/codigo/:codigo')
  vincularPorCodigo(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('codigo') codigo: string,
    @Body() dto: VincularAsesorDto,
  ) {
    return this.asesoresService.vincularPorCodigo(user, codigo, dto);
  }
}

@Controller('disponibilidad')
export class DisponibilidadController {
  constructor(private readonly asesoresService: AsesoresService) {}

  @UseGuards(JwtAuthGuard)
  @Post()
  crearEspacioLibre(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: CrearEspacioLibreDto,
  ) {
    return this.asesoresService.crearEspacioLibre(user, dto);
  }

  @UseGuards(JwtAuthGuard)
  @Get('mis-espacios')
  misEspaciosLibres(@CurrentUserDecorator() user: CurrentUser) {
    return this.asesoresService.misEspaciosLibres(user);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':disponibilidadId')
  desactivarEspacio(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('disponibilidadId') disponibilidadId: string,
  ) {
    return this.asesoresService.desactivarEspacio(user, disponibilidadId);
  }

  @Get('asesor/:asesorId/bloques')
  bloquesDisponibles(
    @Param('asesorId') asesorId: string,
    @Query() query: BloquesDisponiblesDto,
  ) {
    return this.asesoresService.bloquesDisponibles(asesorId, query);
  }
}
