import { IsIn, IsOptional, IsString } from 'class-validator';

export class ActualizarRevisionDocumentoDto {
  @IsIn(['pendiente', 'aprobado', 'rechazado'])
  estadoRevision: string;

  @IsOptional()
  @IsString()
  comentarioRevision?: string;
}
