import { IsOptional, IsString, IsUUID } from 'class-validator';

export class CrearSugerenciaDto {
  @IsUUID()
  tesisId: string;

  @IsOptional()
  @IsUUID()
  documentoTesisId?: string;

  @IsOptional()
  @IsUUID()
  tipoSugerenciaId?: string;

  @IsString()
  detalle: string;
}
