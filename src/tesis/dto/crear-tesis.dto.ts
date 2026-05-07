import { IsOptional, IsString, IsUUID } from 'class-validator';

export class CrearTesisDto {
  @IsUUID()
  universidadId: string;

  @IsString()
  titulo: string;

  @IsOptional()
  @IsString()
  descripcion?: string;
}
