import { IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class RegistrarDocumentoDto {
  @IsUUID()
  tesisId!: string;

  @IsOptional()
  @IsString()
  nombreArchivo?: string;

  @IsOptional()
  @IsString()
  urlArchivoDrive?: string;

  @IsOptional()
  @IsString()
  documentoDriveId?: string;

  @IsOptional()
  @IsString()
  rutaStorage?: string;

  @IsOptional()
  @IsString()
  tipoMime?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  tamanoBytes?: number;
}
