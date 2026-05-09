import { IsIn, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';

export class ActualizarModuloDto {
  @IsOptional()
  @IsIn(['pendiente', 'en_progreso', 'completado'])
  estado?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(100)
  progreso?: number;

  @IsOptional()
  @IsString()
  observacion?: string;
}
