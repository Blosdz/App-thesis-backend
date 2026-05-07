import { IsOptional, IsString, IsUUID } from 'class-validator';

export class CrearObservacionDto {
  @IsUUID()
  tesisId: string;

  @IsOptional()
  @IsUUID()
  documentoTesisId?: string;

  @IsOptional()
  @IsUUID()
  reunionId?: string;

  @IsOptional()
  @IsUUID()
  validationCitaId?: string;

  @IsOptional()
  @IsString()
  titulo?: string;

  @IsOptional()
  @IsString()
  texto?: string;

  @IsOptional()
  @IsString()
  contenidoHtml?: string;

  @IsOptional()
  contenidoDelta?: Record<string, unknown>;

  @IsOptional()
  @IsString()
  tipoOrigen?: string;
}
