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
import { Roles } from '../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { ActualizarCursoDto } from './dto/actualizar-curso.dto';
import { CrearCursoDto } from './dto/crear-curso.dto';
import { CrearMaterialCursoDto } from './dto/crear-material-curso.dto';
import { CursosService } from './cursos.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('cursos')
export class CursosController {
  constructor(private readonly cursosService: CursosService) {}

  @Roles('asesor')
  @Get('asesor/mis-cursos')
  misCursosAsesor(@CurrentUserDecorator() user: CurrentUser) {
    return this.cursosService.misCursosAsesor(user);
  }

  @Roles('asesor')
  @Post('asesor')
  crearCursoAsesor(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: CrearCursoDto,
  ) {
    return this.cursosService.crearCursoAsesor(user, dto);
  }

  @Roles('asesor')
  @Patch('asesor/:cursoId')
  actualizarCursoAsesor(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('cursoId') cursoId: string,
    @Body() dto: ActualizarCursoDto,
  ) {
    return this.cursosService.actualizarCursoAsesor(user, cursoId, dto);
  }

  @Roles('asesor')
  @Post('asesor/:cursoId/materiales')
  crearMaterialAsesor(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('cursoId') cursoId: string,
    @Body() dto: CrearMaterialCursoDto,
  ) {
    return this.cursosService.crearMaterialAsesor(user, cursoId, dto);
  }

  @Roles('asesor')
  @Get('asesor/:cursoId/materiales')
  materialesCursoAsesor(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('cursoId') cursoId: string,
  ) {
    return this.cursosService.materialesCursoAsesor(user, cursoId);
  }

  @Roles('estudiante')
  @Get('mis-cursos')
  misCursosEstudiante(@CurrentUserDecorator() user: CurrentUser) {
    return this.cursosService.misCursosEstudiante(user);
  }

  @Roles('estudiante')
  @Get('asesores/:asesorId')
  cursosDeAsesor(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('asesorId') asesorId: string,
  ) {
    return this.cursosService.cursosDeAsesor(user, asesorId);
  }

  @Roles('estudiante')
  @Post(':cursoId/comprar')
  comprarCurso(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('cursoId') cursoId: string,
  ) {
    return this.cursosService.comprarCurso(user, cursoId);
  }

  @Roles('estudiante')
  @Get(':cursoId')
  detalleCursoEstudiante(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('cursoId') cursoId: string,
  ) {
    return this.cursosService.detalleCursoEstudiante(user, cursoId);
  }
}
