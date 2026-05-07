import { IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class RegistrarDocumentoDto {
  @IsUUID()
  tesisId: string;

  @IsString()
  nombreArchivo: string;

  @IsString()
  urlArchivoDrive: string;

  @IsOptional()
  @IsString()
  carpetaDriveId?: string;

  @IsOptional()
  @IsString()
  documentoDriveId?: string;

  @IsOptional()
  @IsNumber()
  @Min(1)
  version?: number;

  @IsOptional()
  @IsString()
  tipoMime?: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  tamanoBytes?: number;
}
