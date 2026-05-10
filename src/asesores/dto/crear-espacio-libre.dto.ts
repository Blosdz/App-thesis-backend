import {
  IsBoolean,
  IsDateString,
  IsInt,
  IsOptional,
  IsUUID,
  Max,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

export class CrearEspacioLibreDto {
  @IsOptional()
  @IsUUID()
  asesorId?: string;

  @IsDateString()
  inicio!: string;

  @IsDateString()
  fin!: string;

  @IsOptional()
  @IsBoolean()
  usaBloques?: boolean;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  @Min(1)
  duracionBloqueMinutos?: number;

  @IsOptional()
  @IsBoolean()
  recurrente?: boolean;

  @IsOptional()
  @IsInt()
  @Type(() => Number)
  @Min(0)
  @Max(6)
  diaSemana?: number;

  @IsOptional()
  @IsDateString()
  fechaInicio?: string;

  @IsOptional()
  @IsDateString()
  fechaFin?: string;
}
