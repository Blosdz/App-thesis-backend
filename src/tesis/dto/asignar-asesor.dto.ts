import { IsIn, IsOptional, IsUUID } from 'class-validator';

export class AsignarAsesorDto {
  @IsUUID()
  asesorId!: string;

  @IsOptional()
  @IsIn(['principal', 'coasesor'])
  rol?: string;
}
