import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { IniciarPagoPlanDto } from '../planes/dto/iniciar-pago-plan.dto';
import { PlanesService } from '../planes/planes.service';
import { RegistrarPagoDto } from './dto/registrar-pago.dto';
import { RegistrarVoucherDto } from './dto/registrar-voucher.dto';
import { PagosService } from './pagos.service';

@UseGuards(JwtAuthGuard)
@Controller('pagos')
export class PagosController {
  constructor(
    private readonly pagosService: PagosService,
    private readonly planesService: PlanesService,
  ) {}

  @Get('mis-pagos')
  misPagos(@CurrentUserDecorator() user: CurrentUser) {
    return this.pagosService.misPagos(user);
  }

  @Post()
  registrar(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: RegistrarPagoDto,
  ) {
    return this.pagosService.registrar(user, dto);
  }

  @Post(':pagoId/voucher')
  registrarVoucher(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('pagoId') pagoId: string,
    @Body() dto: RegistrarVoucherDto,
  ) {
    return this.pagosService.registrarVoucher(user, pagoId, dto);
  }

  @Post(':pagoId/voucher/archivo')
  @UseInterceptors(FileInterceptor('file'))
  subirVoucher(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('pagoId') pagoId: string,
    @UploadedFile() file: Express.Multer.File,
    @Body('payment_method') paymentMethod?: string,
    @Body('operation_code') operationCode?: string,
  ) {
    return this.pagosService.subirVoucher(user, pagoId, file, {
      paymentMethod,
      codigoOperacion: operationCode,
    });
  }

  @Post('plan/iniciar')
  iniciarPagoPlan(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: IniciarPagoPlanDto,
  ) {
    return this.planesService.iniciarPago(user, dto);
  }
}
