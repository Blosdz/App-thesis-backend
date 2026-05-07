import { IsOptional, IsString, IsUUID } from 'class-validator';

export class GuardarPerfilEstudianteDto {
  @IsString()
  nombres: string;

  @IsString()
  apellidos: string;

  @IsUUID()
  universidadId: string;

  @IsString()
  carrera: string;

  @IsString()
  dni: string;

  @IsOptional()
  @IsString()
  telefono?: string;
}
