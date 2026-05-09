import { IsIn } from 'class-validator';

export class ResponderReservaDto {
  @IsIn(['aceptar', 'rechazar'])
  accion!: string;
}
