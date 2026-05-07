import { IsIn } from 'class-validator';

export class ActualizarEstadoTesisDto {
  @IsIn([
    'borrador',
    'pendiente_pago',
    'en_progreso',
    'revision',
    'completado',
    'cancelado',
  ])
  estado: string;
}
