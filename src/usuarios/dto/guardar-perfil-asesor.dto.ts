import {
  IsEmail,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';

export class GuardarPerfilAsesorDto {
  @IsString()
  @MaxLength(150)
  nombreMostrar!: string;

  @IsOptional()
  @IsUUID()
  universidadId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(150)
  slug?: string;

  @IsOptional()
  @IsEmail()
  emailPublico?: string;

  @IsOptional()
  @IsString()
  biografia?: string;

  @IsOptional()
  @IsString()
  fotoUrl?: string;

  @IsOptional()
  @IsUUID()
  especialidadId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  carrera?: string;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  nivelAcademico?: string;
}
