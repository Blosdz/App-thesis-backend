import {
  IsDateString,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';

export class CrearReunionDto {
  @IsUUID()
  asesorId!: string;

  @IsOptional()
  @IsUUID()
  tesisId?: string;

  @IsOptional()
  @IsUUID()
  disponibilidadId?: string;

  @IsOptional()
  @IsUUID()
  tarifaId?: string;

  @IsDateString()
  inicio!: string;

  @IsDateString()
  fin!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  duracionMinutos?: number;

  @IsOptional()
  @IsNumber()
  @Min(0)
  costoReunion?: number;

  @IsOptional()
  @IsString()
  motivo?: string;

  @IsOptional()
  @IsIn(['virtual', 'presencial'])
  modalidad?: string;

  @IsOptional()
  @IsString()
  lugar?: string;

  @IsOptional()
  @IsString()
  notas?: string;

  @IsOptional()
  @IsString()
  tipoReunion?: string;
}
