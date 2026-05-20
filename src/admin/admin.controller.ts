import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Res,
  UseGuards,
} from '@nestjs/common';
import type { Response } from 'express';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { PagosService } from '../pagos/pagos.service';
import { VerificarPagoDto } from '../pagos/dto/verificar-pago.dto';
import { AdminService } from './admin.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('admin')
@Controller('admin')
export class AdminController {
  constructor(
    private readonly adminService: AdminService,
    private readonly pagosService: PagosService,
  ) {}

  @Get('usuarios')
  listarUsuarios() {
    return this.adminService.listarUsuarios();
  }

  @Post('invitaciones')
  encolarInvitacion(
    @Body() dto: { email: string; name: string; rol?: string },
  ) {
    return this.adminService.encolarInvitacion(dto);
  }

  @Post('invitaciones/procesar')
  procesarInvitaciones(@Body() dto: { batchSize?: number } = {}) {
    return this.adminService.procesarInvitaciones(dto.batchSize);
  }

  @Get('pagos')
  listarPagos() {
    return this.pagosService.adminListar();
  }

  @Get('pagos/pendientes-revision')
  pagosPendientesRevision() {
    return this.pagosService.adminPendientesRevision();
  }

  @Get('pagos/:pagoId')
  obtenerPago(@Param('pagoId') pagoId: string) {
    return this.pagosService.adminObtener(pagoId);
  }

  @Get('pagos/:pagoId/voucher-imagen')
  async obtenerVoucherImagen(
    @Param('pagoId') pagoId: string,
    @Res() res: Response,
  ) {
    return this.pagosService.obtenerVoucherImagen(pagoId, res);
  }

  @Patch('pagos/:pagoId/verificar')
  verificarPago(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('pagoId') pagoId: string,
    @Body() dto: VerificarPagoDto,
  ) {
    return this.pagosService.verificar(user, pagoId, dto);
  }

  @Patch('pagos/:pagoId/verificar-plan')
  verificarPagoPlan(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('pagoId') pagoId: string,
    @Body() dto: VerificarPagoDto,
  ) {
    return this.pagosService.verificar(user, pagoId, dto, true);
  }

  @Patch('reuniones/:reunionId/estado')
  actualizarEstadoReunion(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('reunionId') reunionId: string,
    @Body() dto: { estado: string; nota?: string },
  ) {
    return this.adminService.actualizarEstadoReunion(user, reunionId, dto);
  }

  @Patch('reuniones/:reunionId/pago/verificar')
  verificarPagoReunion(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('reunionId') reunionId: string,
    @Body() dto: VerificarPagoDto,
  ) {
    return this.adminService.verificarPagoReunion(user, reunionId, dto);
  }
}
