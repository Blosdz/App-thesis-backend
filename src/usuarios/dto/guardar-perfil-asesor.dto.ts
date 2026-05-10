import {
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  MaxLength,
} from 'class-validator';
import {
  OptionalTrimmedString,
  TrimString,
} from '../../common/dto/transforms';

export class GuardarPerfilAsesorDto {
  @OptionalTrimmedString()
  @IsString()
  @IsOptional()
  @MaxLength(150)
  nombreMostrar?: string;

  @OptionalTrimmedString()
  @IsOptional()
  @IsUUID()
  universidadId?: string;

  @OptionalTrimmedString()
  @IsOptional()
  @IsString()
  @MaxLength(150)
  slug?: string;

  @OptionalTrimmedString()
  @IsOptional()
  @IsEmail()
  emailPublico?: string;

  @OptionalTrimmedString()
  @IsOptional()
  @IsString()
  biografia?: string;

  @OptionalTrimmedString()
  @IsOptional()
  @IsString()
  @MaxLength(500)
  fotoUrl?: string;

  @OptionalTrimmedString()
  @IsOptional()
  @IsUUID()
  especialidadId?: string;

  @OptionalTrimmedString()
  @IsOptional()
  @IsString()
  @MaxLength(200)
  carrera?: string;

  @OptionalTrimmedString()
  @IsOptional()
  @IsIn(['pregrado', 'maestria', 'doctorado'])
  nivelAcademico?: string;

  @TrimString()
  @IsString()
  @Length(1, 150)
  nombres!: string;

  @TrimString()
  @IsString()
  @Length(1, 150)
  apellidos!: string;

  @TrimString()
  @IsString()
  @Length(1, 20)
  dni!: string;

  @OptionalTrimmedString()
  @IsOptional()
  @IsString()
  @MaxLength(30)
  telefono?: string;
}
