import { Body, Controller, Get, Put, UseGuards } from '@nestjs/common';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { GuardarPerfilAsesorDto } from './dto/guardar-perfil-asesor.dto';
import { GuardarPerfilEstudianteDto } from './dto/guardar-perfil-estudiante.dto';
import { UsuariosService } from './usuarios.service';

@Controller('usuarios')
@UseGuards(JwtAuthGuard, RolesGuard)
export class UsuariosController {
  constructor(private readonly usuariosService: UsuariosService) {}

  @Get('me')
  me(@CurrentUserDecorator() user: CurrentUser) {
    return this.usuariosService.me(user);
  }

  @Put('perfil/estudiante')
  @Roles('estudiante')
  guardarPerfilEstudiante(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: GuardarPerfilEstudianteDto,
  ) {
    return this.usuariosService.guardarPerfilEstudiante(user, dto);
  }

  @Put('perfil/asesor')
  @Roles('asesor')
  guardarPerfilAsesor(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: GuardarPerfilAsesorDto,
  ) {
    return this.usuariosService.guardarPerfilAsesor(user, dto);
  }
}
