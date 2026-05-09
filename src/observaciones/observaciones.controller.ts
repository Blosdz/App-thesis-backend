import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { CrearObservacionDto } from './dto/crear-observacion.dto';
import { ObservacionesService } from './observaciones.service';

@UseGuards(JwtAuthGuard)
@Controller('observaciones')
export class ObservacionesController {
  constructor(private readonly observacionesService: ObservacionesService) {}

  @Post('tesis')
  crear(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: CrearObservacionDto,
  ) {
    return this.observacionesService.crear(user, dto);
  }

  @Get('tesis/:tesisId/historial')
  historial(@Param('tesisId') tesisId: string) {
    return this.observacionesService.historial(tesisId);
  }
}
