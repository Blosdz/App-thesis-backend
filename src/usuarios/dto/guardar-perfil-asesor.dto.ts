import { IsEmail, IsOptional, IsString, IsUUID } from 'class-validator';

export class GuardarPerfilAsesorDto {
  @IsString()
  nombreMostrar: string;

  @IsUUID()
  universidadId: string;

  @IsString()
  slug: string;

  @IsEmail()
  emailPublico: string;

  @IsString()
  biografia: string;

  @IsOptional()
  @IsString()
  fotoUrl?: string;

  @IsUUID()
  especialidadId: string;

  @IsString()
  carrera: string;

  @IsString()
  nivelAcademico: string;

  @IsString()
  nombres: string;

  @IsString()
  apellidos: string;

  @IsString()
  dni: string;

  @IsOptional()
  @IsString()
  telefono?: string;
}
