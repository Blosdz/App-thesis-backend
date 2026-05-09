import { IsIn } from 'class-validator';

export class CambiarEstadoRelacionDto {
  @IsIn(['pendiente', 'activo', 'cancelado', 'completado'])
  estado!: string;
}
