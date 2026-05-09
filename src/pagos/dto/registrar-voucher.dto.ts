import { IsNumber, IsOptional, IsString } from 'class-validator';

export class RegistrarVoucherDto {
  @IsOptional()
  @IsString()
  codigoOperacion?: string;

  @IsOptional()
  @IsString()
  documentoDriveId?: string;

  @IsOptional()
  @IsString()
  urlArchivoDrive?: string;

  @IsOptional()
  @IsString()
  nombreArchivoVoucher?: string;

  @IsOptional()
  @IsString()
  tipoMimeVoucher?: string;

  @IsOptional()
  @IsNumber()
  tamanoBytesVoucher?: number;

  @IsOptional()
  @IsString()
  paymentMethod?: string;
}
