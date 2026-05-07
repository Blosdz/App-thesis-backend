import {
  IsBoolean,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';

export class RegistrarLeadDto {
  @IsString()
  telefono: string;

  @IsOptional()
  @IsString()
  nombre?: string;

  @IsOptional()
  @IsString()
  email?: string;

  @IsOptional()
  @IsString()
  nivelAcademico?: string;

  @IsOptional()
  @IsString()
  tipoTesisCodigo?: string;

  @IsOptional()
  @IsBoolean()
  requiereAnalisisEstadistico?: boolean;

  @IsOptional()
  @IsUUID()
  planRecomendadoId?: string;

  @IsOptional()
  @IsNumber()
  precioCotizado?: number;

  @IsOptional()
  metadata?: Record<string, unknown>;
}
