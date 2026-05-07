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
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { ActualizarEstadoTesisDto } from './dto/actualizar-estado-tesis.dto';
import { CrearTesisDto } from './dto/crear-tesis.dto';
import { TesisService } from './tesis.service';

@Controller('tesis')
@UseGuards(JwtAuthGuard)
export class TesisController {
  constructor(private readonly tesisService: TesisService) {}

  @Get()
  listar(@CurrentUserDecorator() user: CurrentUser) {
    return this.tesisService.listar(user);
  }

  @Get(':id')
  obtenerDetalle(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('id') tesisId: string,
  ) {
    return this.tesisService.obtenerDetalle(user, tesisId);
  }

  @Post()
  crear(@CurrentUserDecorator() user: CurrentUser, @Body() dto: CrearTesisDto) {
    return this.tesisService.crear(user, dto);
  }

  @Patch(':id/estado')
  actualizarEstado(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('id') tesisId: string,
    @Body() dto: ActualizarEstadoTesisDto,
  ) {
    return this.tesisService.actualizarEstado(user, tesisId, dto);
  }
}
