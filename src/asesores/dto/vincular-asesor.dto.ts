import { IsOptional, IsString, MaxLength } from 'class-validator';

export class VincularAsesorDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  mensaje?: string;
}
