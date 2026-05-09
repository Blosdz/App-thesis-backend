import { IsDateString } from 'class-validator';

export class BloquesDisponiblesDto {
  @IsDateString()
  desde!: string;

  @IsDateString()
  hasta!: string;
}
