import { IsUUID } from 'class-validator';

export class CrearModuloTesisDto {
  @IsUUID()
  moduloListaId: string;
}
