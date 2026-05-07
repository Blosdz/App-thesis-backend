import { IsISO8601, IsOptional, IsString, IsUUID } from 'class-validator';

export class CrearReunionDto {
  @IsUUID()
  disponibilidadId: string;

  @IsISO8601()
  inicio: string;

  @IsISO8601()
  fin: string;

  @IsOptional()
  @IsUUID()
  tesisId?: string;

  @IsOptional()
  @IsString()
  motivo?: string;

  @IsOptional()
  @IsString()
  modalidad?: string;

  @IsOptional()
  @IsString()
  lugar?: string;

  @IsOptional()
  @IsString()
  enlaceReunion?: string;

  @IsOptional()
  @IsString()
  notas?: string;
}
