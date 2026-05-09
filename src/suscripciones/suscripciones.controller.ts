import { Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { SuscripcionesService } from './suscripciones.service';

@UseGuards(JwtAuthGuard)
@Controller('suscripciones')
export class SuscripcionesController {
  constructor(private readonly suscripcionesService: SuscripcionesService) {}

  @Get('mi-suscripcion')
  miSuscripcion(@CurrentUserDecorator() user: CurrentUser) {
    return this.suscripcionesService.miSuscripcion(user);
  }

  @Get('estudiante/:estudianteId')
  suscripcionEstudiante(@Param('estudianteId') estudianteId: string) {
    return this.suscripcionesService.suscripcionEstudiante(estudianteId);
  }
}

@UseGuards(JwtAuthGuard)
@Controller('beneficios')
export class BeneficiosController {
  constructor(private readonly suscripcionesService: SuscripcionesService) {}

  @Get('estudiante/:estudianteId/:codigo')
  beneficioDisponible(
    @Param('estudianteId') estudianteId: string,
    @Param('codigo') codigo: string,
  ) {
    return this.suscripcionesService.beneficioDisponible(estudianteId, codigo);
  }

  @Post(':beneficioConsumoId/consumir')
  consumirBeneficio(@Param('beneficioConsumoId') beneficioConsumoId: string) {
    return this.suscripcionesService.consumirBeneficio(beneficioConsumoId);
  }
}
