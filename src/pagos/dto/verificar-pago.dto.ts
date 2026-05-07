import { IsBoolean, IsOptional, IsString } from 'class-validator';

export class VerificarPagoDto {
  @IsBoolean()
  aprobado: boolean;

  @IsOptional()
  @IsString()
  notaVerificacion?: string;
}
