import { IsOptional, IsString, IsUUID } from 'class-validator';

export class CrearSugerenciaDto {
  @IsUUID()
  tesisId!: string;

  @IsOptional()
  @IsUUID()
  documentoTesisId?: string;

  @IsString()
  sugerencia!: string;

  @IsOptional()
  @IsString()
  detalle?: string;

  @IsOptional()
  @IsUUID()
  tipoSugerenciaId?: string;
}
