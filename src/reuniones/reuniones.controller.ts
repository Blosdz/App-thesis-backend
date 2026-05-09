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
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { ActualizarEstadoReunionDto } from './dto/actualizar-estado-reunion.dto';
import { CancelarReunionDto } from './dto/cancelar-reunion.dto';
import { CrearReunionDto } from './dto/crear-reunion.dto';
import { GuardarGoogleMeetDto } from './dto/guardar-google-meet.dto';
import { ResponderReservaDto } from './dto/responder-reserva.dto';
import { ReunionesService } from './reuniones.service';

@UseGuards(JwtAuthGuard)
@Controller('reuniones')
export class ReunionesController {
  constructor(private readonly reunionesService: ReunionesService) {}

  @Post()
  crear(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: CrearReunionDto,
  ) {
    return this.reunionesService.crear(user, dto);
  }

  @Post('asesoria')
  crearAsesoria(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: CrearReunionDto,
  ) {
    return this.reunionesService.crearSolicitud(user, {
      ...dto,
      tipoReunion: 'asesoria',
    });
  }

  @Post('presustentacion')
  crearPresustentacion(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: CrearReunionDto,
  ) {
    return this.reunionesService.crearSolicitud(user, {
      ...dto,
      tipoReunion: 'presustentacion',
    });
  }

  @Get('mis-citas-estudiante')
  misCitasEstudiante(@CurrentUserDecorator() user: CurrentUser) {
    return this.reunionesService.misCitasEstudiante(user);
  }

  @Get('mis-citas-asesor')
  misCitasAsesor(@CurrentUserDecorator() user: CurrentUser) {
    return this.reunionesService.misCitasAsesor(user);
  }

  @Get('validaciones/estudiante')
  historialValidacionesEstudiante(
    @CurrentUserDecorator() user: CurrentUser,
    @Query('status') status?: string,
  ) {
    return this.reunionesService.historialValidacionesEstudiante(user, status);
  }

  @Get('validaciones/asesor')
  historialValidacionesAsesor(
    @CurrentUserDecorator() user: CurrentUser,
    @Query('status') status?: string,
  ) {
    return this.reunionesService.historialValidacionesAsesor(user, status);
  }

  @Get(':reunionId')
  detalle(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('reunionId') reunionId: string,
  ) {
    return this.reunionesService.detalle(user, reunionId);
  }

  @Post(':reunionId/cancelar')
  cancelar(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('reunionId') reunionId: string,
    @Body() dto: CancelarReunionDto,
  ) {
    return this.reunionesService.cancelar(user, reunionId, dto);
  }

  @Patch(':reunionId/estado')
  actualizarEstado(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('reunionId') reunionId: string,
    @Body() dto: ActualizarEstadoReunionDto,
  ) {
    return this.reunionesService.actualizarEstado(user, reunionId, dto);
  }

  @Post('validaciones/:validationCitaId/responder')
  responderReserva(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('validationCitaId') validationCitaId: string,
    @Body() dto: ResponderReservaDto,
  ) {
    return this.reunionesService.responderReserva(user, validationCitaId, dto);
  }

  @Post('validaciones/:validationCitaId/aprobar-pago')
  aprobarPagoReserva(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('validationCitaId') validationCitaId: string,
    @Body() dto: GuardarGoogleMeetDto,
  ) {
    return this.reunionesService.aprobarPagoReserva(user, validationCitaId, dto);
  }

  @Post(':reunionId/google-meet')
  guardarGoogleMeet(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('reunionId') reunionId: string,
    @Body() dto: GuardarGoogleMeetDto,
  ) {
    return this.reunionesService.guardarGoogleMeet(user, reunionId, dto);
  }

  @Post(':reunionId/google-meet/crear')
  crearGoogleMeet(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('reunionId') reunionId: string,
  ) {
    return this.reunionesService.crearGoogleMeet(user, reunionId);
  }
}
