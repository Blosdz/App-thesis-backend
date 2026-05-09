import { IsEmail, IsString, MinLength } from 'class-validator';

export class PasswordResetRequestDto {
  @IsEmail()
  email!: string;
}

export class PasswordResetDto {
  @IsString()
  token!: string;

  @IsString()
  @MinLength(8)
  contrasenaNueva!: string;
}
