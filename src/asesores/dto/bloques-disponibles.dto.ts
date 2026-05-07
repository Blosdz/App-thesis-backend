import { IsDateString, IsUUID } from 'class-validator';

export class BloquesDisponiblesDto {
  @IsUUID()
  asesorId: string;

  @IsDateString()
  desde: string;

  @IsDateString()
  hasta: string;
}
