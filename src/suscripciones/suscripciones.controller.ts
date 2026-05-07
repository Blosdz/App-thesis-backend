import { Controller, Get, UseGuards } from '@nestjs/common';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { SuscripcionesService } from './suscripciones.service';

@Controller('suscripciones')
@UseGuards(JwtAuthGuard)
export class SuscripcionesController {
  constructor(private readonly suscripcionesService: SuscripcionesService) {}

  @Get('me')
  obtenerActual(@CurrentUserDecorator() user: CurrentUser) {
    return this.suscripcionesService.obtenerActual(user);
  }
}
