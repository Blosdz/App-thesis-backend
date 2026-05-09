import { IsOptional, IsString, IsUUID } from 'class-validator';

export class CrearObservacionDto {
  @IsUUID()
  tesisId!: string;

  @IsOptional()
  @IsUUID()
  documentoTesisId?: string;

  @IsString()
  texto!: string;

  @IsOptional()
  @IsString()
  titulo?: string;

  @IsOptional()
  @IsString()
  contenidoHtml?: string;

  @IsOptional()
  contenidoDelta?: Record<string, unknown>;
}
