import { IsOptional, IsString, IsUUID } from 'class-validator';

export class UploadDocumentoDto {
  @IsUUID()
  tesisId: string;

  @IsOptional()
  @IsString()
  carpetaDriveId?: string;

  @IsOptional()
  @IsString()
  nombreArchivo?: string;
}
