import { IsBoolean, IsOptional, IsString } from 'class-validator';

export class ValidarCitaAdminDto {
  @IsBoolean()
  aprobado: boolean;

  @IsOptional()
  @IsString()
  notasAdmin?: string;

  @IsOptional()
  @IsString()
  enlaceReunion?: string;
}
