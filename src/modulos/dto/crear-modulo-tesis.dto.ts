import { IsUUID } from 'class-validator';

export class CrearModuloTesisDto {
  @IsUUID()
  tesisId!: string;

  @IsUUID()
  moduloListaId!: string;
}
