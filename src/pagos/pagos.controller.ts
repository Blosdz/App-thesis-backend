import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { Roles } from '../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { PagosService } from './pagos.service';
import { RegistrarPagoDto } from './dto/registrar-pago.dto';
import { RegistrarVoucherDto } from './dto/registrar-voucher.dto';
import { UploadVoucherDto } from './dto/upload-voucher.dto';
import { VerificarPagoDto } from './dto/verificar-pago.dto';

@Controller('pagos')
@UseGuards(JwtAuthGuard, RolesGuard)
export class PagosController {
  constructor(private readonly pagosService: PagosService) {}

  @Get()
  listar(@CurrentUserDecorator() user: CurrentUser) {
    return this.pagosService.listar(user);
  }

  @Post()
  registrar(
    @CurrentUserDecorator() user: CurrentUser,
    @Body() dto: RegistrarPagoDto,
  ) {
    return this.pagosService.registrar(user, dto);
  }

  @Post(':id/voucher')
  registrarVoucher(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('id') pagoId: string,
    @Body() dto: RegistrarVoucherDto,
  ) {
    return this.pagosService.registrarVoucher(user, pagoId, dto);
  }

  @Post(':id/voucher/upload')
  @UseInterceptors(FileInterceptor('file'))
  uploadVoucher(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('id') pagoId: string,
    @UploadedFile() file: Express.Multer.File,
    @Body() dto: UploadVoucherDto,
  ) {
    return this.pagosService.uploadVoucher(user, pagoId, file, dto);
  }

  @Patch(':id/verificar')
  @Roles('admin')
  verificar(@Param('id') pagoId: string, @Body() dto: VerificarPagoDto) {
    return this.pagosService.verificar(pagoId, dto);
  }
}
