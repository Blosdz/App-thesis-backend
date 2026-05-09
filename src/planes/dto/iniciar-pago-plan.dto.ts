import { IsOptional, IsString, IsUUID, MaxLength } from 'class-validator';

export class IniciarPagoPlanDto {
  @IsUUID()
  planId!: string;

  @IsOptional()
  @IsUUID()
  tesisId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(150)
  codigoOperacion?: string;
}
