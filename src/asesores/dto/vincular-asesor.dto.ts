import { IsString } from 'class-validator';

export class VincularAsesorDto {
  @IsString()
  valor: string;
}
