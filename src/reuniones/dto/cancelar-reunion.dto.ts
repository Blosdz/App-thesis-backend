import { IsOptional, IsString } from 'class-validator';

export class CancelarReunionDto {
  @IsOptional()
  @IsString()
  motivo?: string;
}
