import { IsIn } from 'class-validator';

export class ResponderReservaDto {
  @IsIn(['aprobar', 'rechazar', 'cancelar'])
  accion: string;
}
