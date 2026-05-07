import { IsOptional, IsString, IsUUID } from 'class-validator';

export class AsignarTesisAsesorDto {
  @IsUUID()
  tesisId: string;

  @IsUUID()
  asesorId: string;

  @IsOptional()
  @IsString()
  rol?: string;
}
