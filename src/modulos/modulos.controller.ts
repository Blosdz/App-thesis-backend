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

@UseGuards(JwtAuthGuard)
@Controller('modulos')
export class ModulosController {
  constructor(private readonly modulosService: ModulosService) {}

  @Get()
  listarCatalogo() {
    return this.modulosService.listarCatalogo();
  }

  @Get('tesis/:tesisId')
  listarPorTesis(@Param('tesisId') tesisId: string) {
    return this.modulosService.listarPorTesis(tesisId);
  }

  @Post('tesis')
  crearParaTesis(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: CrearModuloTesisDto,
  ) {
    return this.modulosService.crearParaTesis(user, dto);
  }

  @Patch(':moduloId')
  actualizar(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('moduloId') moduloId: string,
    @Body() dto: ActualizarModuloDto,
  ) {
    return this.modulosService.actualizar(user, moduloId, dto);
  }
}
