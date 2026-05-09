import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { CotizarTesisPlanDto } from './dto/cotizar-tesis-plan.dto';
import { IniciarPagoPlanDto } from './dto/iniciar-pago-plan.dto';
import { PlanesService } from './planes.service';

@Controller('planes')
export class PlanesController {
  constructor(private readonly planesService: PlanesService) {}

  @Get()
  listar() {
    return this.planesService.listar();
  }

  @Get('disponibles')
  disponibles() {
    return this.planesService.disponibles();
  }

  @Post('cotizar')
  cotizar(@Body() dto: CotizarTesisPlanDto) {
    return this.planesService.cotizar(dto);
  }

  @UseGuards(JwtAuthGuard)
  @Post('iniciar-pago')
  iniciarPago(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: IniciarPagoPlanDto,
  ) {
    return this.planesService.iniciarPago(user, dto);
  }
}
