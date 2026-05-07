import { IsEmail, IsOptional, IsString } from 'class-validator';

export class CreateInvitationDto {
  @IsEmail()
  email: string;

  @IsOptional()
  @IsString()
  nombre?: string;

  @IsOptional()
  payload?: Record<string, unknown>;
}
