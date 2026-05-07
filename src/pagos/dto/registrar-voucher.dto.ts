import { IsNumber, IsOptional, IsString, Min } from 'class-validator';

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
  @Min(0)
  tamanoBytesVoucher?: number;

  @IsOptional()
  metadata?: Record<string, unknown>;
}
