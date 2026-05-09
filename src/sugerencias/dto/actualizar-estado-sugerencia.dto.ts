import { IsIn, IsOptional, IsString } from 'class-validator';

export class ActualizarEstadoSugerenciaDto {
  @IsIn(['pendiente', 'marcado_por_estudiante', 'verificado', 'rechazado'])
  estado!: string;

  @IsOptional()
  @IsString()
  comentario?: string;
}
