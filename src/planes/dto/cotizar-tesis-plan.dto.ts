import {
  IsBoolean,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';

export class CotizarTesisPlanDto {
  @IsUUID()
  planId!: string;

  @IsUUID()
  tipoTesisId!: string;

  @IsString()
  @MaxLength(30)
  nivelAcademico!: string;

  @IsOptional()
  @IsBoolean()
  requiereAnalisisEstadistico?: boolean;
}
