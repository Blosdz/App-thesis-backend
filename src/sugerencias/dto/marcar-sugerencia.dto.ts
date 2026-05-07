import { IsBoolean, IsOptional, IsString } from 'class-validator';

export class MarcarSugerenciaDto {
  @IsBoolean()
  aplicado: boolean;

  @IsOptional()
  @IsString()
  comentario?: string;
}
