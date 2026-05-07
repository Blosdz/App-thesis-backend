import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { ComprarPlanDto } from './dto/comprar-plan.dto';
import { PlanesService } from './planes.service';

@Controller('planes')
export class PlanesController {
  constructor(private readonly planesService: PlanesService) {}

  @Get()
  listar() {
    return this.planesService.listar();
  }

  @Post('comprar')
  @UseGuards(JwtAuthGuard)
  comprar(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: ComprarPlanDto,
  ) {
    return this.planesService.comprar(user, dto);
  }
}
