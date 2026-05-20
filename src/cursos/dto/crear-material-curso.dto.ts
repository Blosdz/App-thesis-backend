import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';

export class CrearMaterialCursoDto {
  @IsString()
  titulo!: string;

  @IsOptional()
  @IsString()
  descripcion?: string;

  @IsOptional()
  @IsIn(['documento', 'video', 'link', 'plantilla', 'imagen', 'zip', 'otro'])
  tipo?: string;

  @IsOptional()
  @IsString()
  driveFileId?: string;

  @IsOptional()
  @IsString()
  driveFolderId?: string;

  @IsOptional()
  @IsString()
  urlDrive?: string;

  @IsOptional()
  @IsString()
  nombreArchivo?: string;

  @IsOptional()
  @IsString()
  tipoMime?: string;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  @Min(0)
  tamanoBytes?: number;

  @IsOptional()
  @IsString()
  urlExterna?: string;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  @Min(1)
  orden?: number;

  @IsOptional()
  @IsBoolean()
  esVistaPrevia?: boolean;
}
