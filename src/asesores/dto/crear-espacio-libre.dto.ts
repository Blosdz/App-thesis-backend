import {
  IsBoolean,
  IsDateString,
  IsISO8601,
  IsNumber,
  IsOptional,
  Min,
} from 'class-validator';

export class CrearEspacioLibreDto {
  @IsISO8601()
  inicio: string;

  @IsISO8601()
  fin: string;

  @IsOptional()
  @IsBoolean()
  usaBloques?: boolean;

  @IsOptional()
  @IsNumber()
  @Min(1)
  duracionBloqueMinutos?: number;

  @IsOptional()
  @IsBoolean()
  recurrente?: boolean;

  @IsOptional()
  @IsNumber({}, { each: true })
  diasSemana?: number[];

  @IsOptional()
  @IsDateString()
  fechaInicio?: string;

  @IsOptional()
  @IsDateString()
  fechaFin?: string;
}
