import {
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class CrearTesisDto {
  @IsOptional()
  @IsUUID()
  universidadId?: string;

  @IsString()
  @MaxLength(300)
  titulo!: string;

  @IsOptional()
  @IsString()
  descripcion?: string;
}

export class CrearTesisConPlanDto extends CrearTesisDto {
  @IsUUID()
  planId!: string;

  @IsUUID()
  tipoTesisId!: string;

  @IsOptional()
  @IsUUID()
  programaId?: string;

  @IsString()
  @MaxLength(30)
  nivelAcademico!: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(20)
  cantidadVariables?: number;

  @IsOptional()
  @IsBoolean()
  requiereAnalisisEstadistico?: boolean;

  @IsOptional()
  @IsBoolean()
  esArquitecturaDiseno?: boolean;

  @IsOptional()
  @IsIn([
    'borrador',
    'pendiente_pago',
    'en_progreso',
    'revision',
    'completado',
    'cancelado',
  ])
  estadoTesis?: string;
}
