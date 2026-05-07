import { IsOptional, IsString } from 'class-validator';

export class AprobarPagoReservaDto {
  @IsOptional()
  @IsString()
  enlaceReunion?: string;

  @IsOptional()
  @IsString()
  lugar?: string;

  @IsOptional()
  @IsString()
  notas?: string;
}
