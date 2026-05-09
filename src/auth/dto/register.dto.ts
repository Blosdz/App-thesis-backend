import {
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';
import type { CurrentUser } from '../../common/interfaces/current-user.interface';

export class RegisterDto {
  @IsEmail()
  email!: string;

  @IsIn(['admin', 'asesor', 'estudiante'])
  rol!: CurrentUser['rol'];

  @IsOptional()
  @IsString()
  @MinLength(8)
  contrasena?: string;
}
