import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class ActualizarCursoDto {
  @IsOptional()
  @IsString()
  @MaxLength(180)
  titulo?: string;

  @IsOptional()
  @IsString()
  descripcion?: string;

  @IsOptional()
  @IsNumber()
  @Type(() => Number)
  @Min(0)
  precio?: number;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  moneda?: string;

  @IsOptional()
  @IsString()
  portadaDriveId?: string;

  @IsOptional()
  @IsString()
  portadaUrlDrive?: string;

  @IsOptional()
  @IsIn(['borrador', 'publicado', 'pausado', 'archivado'])
  estado?: string;

  @IsOptional()
  @IsBoolean()
  activo?: boolean;
}
