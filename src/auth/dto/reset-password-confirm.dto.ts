import { IsString, MinLength } from 'class-validator';

export class ResetPasswordConfirmDto {
  @IsString()
  token: string;

  @IsString()
  @MinLength(8)
  contrasenaNueva: string;
}
