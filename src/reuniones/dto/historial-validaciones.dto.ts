import { IsOptional, IsString } from 'class-validator';

export class HistorialValidacionesDto {
  @IsOptional()
  @IsString()
  status?: string;
}
