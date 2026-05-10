import { IsOptional, IsString, IsUUID } from 'class-validator';

export class ListarAsesoresQueryDto {
  @IsOptional()
  @IsString()
  buscar?: string;

  @IsOptional()
  @IsUUID()
  universidadId?: string;

  @IsOptional()
  @IsUUID()
  especialidadId?: string;

  @IsOptional()
  @IsString()
  carrera?: string;

  @IsOptional()
  @IsString()
  nivelAcademico?: string;
}
