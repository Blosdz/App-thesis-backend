import { IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';

export class RegistrarPagoDto {
  @IsString()
  concepto: string;

  @IsNumber()
  @Min(0)
  monto: number;

  @IsOptional()
  @IsUUID()
  tesisId?: string;

  @IsOptional()
  metadata?: Record<string, unknown>;
}
