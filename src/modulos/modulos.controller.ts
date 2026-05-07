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
import { ActualizarModuloDto } from './dto/actualizar-modulo.dto';
import { CrearModuloTesisDto } from './dto/crear-modulo-tesis.dto';
import { ModulosService } from './modulos.service';

@Controller('modulos')
@UseGuards(JwtAuthGuard)
export class ModulosController {
  constructor(private readonly modulosService: ModulosService) {}

  @Get('tesis/:tesisId')
  listarPorTesis(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
  ) {
    return this.modulosService.listarPorTesis(user, tesisId);
  }

  @Post('tesis/:tesisId')
  crearParaTesis(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @Body() dto: CrearModuloTesisDto,
  ) {
    return this.modulosService.crearParaTesis(user, tesisId, dto);
  }

  @Patch(':id')
  actualizar(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('id') moduloId: string,
    @Body() dto: ActualizarModuloDto,
  ) {
    return this.modulosService.actualizar(user, moduloId, dto);
  }
}
