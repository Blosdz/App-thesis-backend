import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { AprobarPagoReservaDto } from './dto/aprobar-pago-reserva.dto';
import { CancelarReunionDto } from './dto/cancelar-reunion.dto';
import { CrearReunionDto } from './dto/crear-reunion.dto';
import { HistorialValidacionesDto } from './dto/historial-validaciones.dto';
import { ListarReunionesDto } from './dto/listar-reuniones.dto';
import { ResponderReservaDto } from './dto/responder-reserva.dto';
import { ValidarCitaAdminDto } from './dto/validar-cita-admin.dto';
import { ReunionesService } from './reuniones.service';

@Controller('reuniones')
@UseGuards(JwtAuthGuard)
export class ReunionesController {
  constructor(private readonly reunionesService: ReunionesService) {}

  @Get()
  listar(
    @CurrentUserDecorator() user: CurrentUser,
    @Query() query: ListarReunionesDto,
  ) {
    return this.reunionesService.listar(user, query);
  }

  @Post()
  crear(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: CrearReunionDto,
  ) {
    return this.reunionesService.crear(user, dto);
  }

  @Patch(':id/cancelar')
  cancelar(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('id') reunionId: string,
    @Body() dto: CancelarReunionDto,
  ) {
    return this.reunionesService.cancelar(user, reunionId, dto);
  }

  @Get('validaciones/estudiante')
  historialEstudiante(
    @CurrentUserDecorator() user: CurrentUser,
    @Query() query: HistorialValidacionesDto,
  ) {
    return this.reunionesService.historialEstudiante(user, query);
  }

  @Get('validaciones/asesor')
  historialAsesor(
    @CurrentUserDecorator() user: CurrentUser,
    @Query() query: HistorialValidacionesDto,
  ) {
    return this.reunionesService.historialAsesor(user, query);
  }

  @Post('validaciones/:id/responder')
  responderReserva(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('id') validationCitaId: string,
    @Body() dto: ResponderReservaDto,
  ) {
    return this.reunionesService.responderReserva(user, validationCitaId, dto);
  }

  @Post('validaciones/:id/aprobar-pago')
  aprobarPagoReserva(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('id') validationCitaId: string,
    @Body() dto: AprobarPagoReservaDto,
  ) {
    return this.reunionesService.aprobarPagoReserva(
      user,
      validationCitaId,
      dto,
    );
  }

  @Patch('validaciones/:id/admin')
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  validarCitaAdmin(
    @Param('id') validationCitaId: string,
    @Body() dto: ValidarCitaAdminDto,
  ) {
    return this.reunionesService.validarCitaAdmin(validationCitaId, dto);
  }

  @Post(':id/meet')
  crearMeet(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('id') reunionId: string,
  ) {
    return this.reunionesService.crearMeet(user, reunionId);
  }
}
