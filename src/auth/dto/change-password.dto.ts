import { IsString, MinLength } from 'class-validator';

export class ChangePasswordDto {
  @IsString()
  @MinLength(8)
  contrasenaActual: string;

  @IsString()
  @MinLength(8)
  contrasenaNueva: string;
}
