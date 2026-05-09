import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class GuardarPerfilEstudianteDto {
  @IsString()
  @MaxLength(150)
  nombres!: string;

  @IsString()
  @MaxLength(150)
  apellidos!: string;

  @IsOptional()
  @IsUUID()
  universidadId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(150)
  carrera?: string;
}
