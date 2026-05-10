import { IsOptional, IsString, Length, MaxLength } from 'class-validator';

export class VincularPorCodigoDto {
  @IsString()
  @Length(3, 100)
  codigo: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  mensaje?: string;
}
