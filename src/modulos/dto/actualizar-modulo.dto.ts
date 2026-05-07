import {
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  Min,
} from 'class-validator';

export class ActualizarModuloDto {
  @IsIn(['pendiente', 'en_progreso', 'completado'])
  estado: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  @Max(100)
  progreso?: number;

  @IsOptional()
  @IsString()
  observacion?: string;
}
