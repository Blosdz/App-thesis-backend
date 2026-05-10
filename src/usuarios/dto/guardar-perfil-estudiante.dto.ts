import { IsOptional, IsString, IsUUID, Length, MaxLength } from 'class-validator';
import {
  OptionalTrimmedString,
  TrimString,
} from '../../common/dto/transforms';

export class GuardarPerfilEstudianteDto {
  @TrimString()
  @IsString()
  @Length(1, 150)
  nombres!: string;

  @TrimString()
  @IsString()
  @Length(1, 150)
  apellidos!: string;

  @OptionalTrimmedString()
  @IsOptional()
  @IsUUID()
  universidadId?: string;

  @OptionalTrimmedString()
  @IsOptional()
  @IsString()
  @MaxLength(150)
  carrera?: string;

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
