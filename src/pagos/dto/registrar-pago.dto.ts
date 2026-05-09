import {
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
} from 'class-validator';

export class RegistrarPagoDto {
  @IsString()
  @MaxLength(200)
  concepto!: string;

  @IsNumber()
  @Min(0)
  monto!: number;

  @IsOptional()
  @IsString()
  @MaxLength(150)
  codigoOperacion?: string;

  @IsOptional()
  @IsUUID()
  tesisId?: string;
}
