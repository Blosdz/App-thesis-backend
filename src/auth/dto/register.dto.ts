import {
  IsEmail,
  IsIn,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';

export class RegisterDto {
  @IsEmail()
  email: string;

  @IsIn(['admin', 'asesor', 'estudiante'])
  rol: 'admin' | 'asesor' | 'estudiante';

  @IsOptional()
  @IsString()
  @MinLength(8)
  contrasena?: string;
}
