import { Type } from 'class-transformer';
import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class CrearCursoDto {
  @IsString()
  @MaxLength(180)
  titulo!: string;

  @IsOptional()
  @IsString()
  descripcion?: string;

  @IsNumber()
  @Type(() => Number)
  @Min(0)
  precio!: number;

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
}
