import { IsIn, IsOptional, IsString } from 'class-validator';

export class ActualizarEstadoReunionDto {
  @IsIn(['pendiente', 'confirmado', 'cancelado', 'completado'])
  estado!: string;

  @IsOptional()
  @IsString()
  comentario?: string;
}
