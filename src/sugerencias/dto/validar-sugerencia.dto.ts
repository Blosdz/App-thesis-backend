import { IsBoolean, IsOptional, IsString } from 'class-validator';

export class ValidarSugerenciaDto {
  @IsBoolean()
  aprobado: boolean;

  @IsOptional()
  @IsString()
  comentarioAsesor?: string;
}
