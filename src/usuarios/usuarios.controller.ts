import { Body, Controller, Get, Put, UseGuards } from '@nestjs/common';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { GuardarPerfilAsesorDto } from './dto/guardar-perfil-asesor.dto';
import { GuardarPerfilEstudianteDto } from './dto/guardar-perfil-estudiante.dto';
import { UsuariosService } from './usuarios.service';

@UseGuards(JwtAuthGuard)
@Controller()
export class UsuariosController {
  constructor(private readonly usuariosService: UsuariosService) {}

  @Get('perfil/estudiante')
  obtenerPerfilEstudiante(@CurrentUserDecorator() user: CurrentUser) {
    return this.usuariosService.obtenerPerfilEstudiante(user);
  }

  @Put('perfil/estudiante')
  guardarPerfilEstudiante(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: GuardarPerfilEstudianteDto,
  ) {
    return this.usuariosService.guardarPerfilEstudiante(user, dto);
  }

  @Get('perfil/asesor')
  obtenerPerfilAsesor(@CurrentUserDecorator() user: CurrentUser) {
    return this.usuariosService.obtenerPerfilAsesor(user);
  }

  @Put('perfil/asesor')
  guardarPerfilAsesor(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: GuardarPerfilAsesorDto,
  ) {
    return this.usuariosService.guardarPerfilAsesor(user, dto);
  }

  @Get('usuarios/mi-rol')
  obtenerMiRol(@CurrentUserDecorator() user: CurrentUser) {
    return this.usuariosService.obtenerMiRol(user);
  }
}
