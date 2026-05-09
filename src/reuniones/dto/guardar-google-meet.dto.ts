import { IsOptional, IsString } from 'class-validator';

export class GuardarGoogleMeetDto {
  @IsOptional()
  @IsString()
  googleEventId?: string;

  @IsOptional()
  @IsString()
  enlaceReunion?: string;

  @IsOptional()
  @IsString()
  meetCodigo?: string;

  @IsOptional()
  @IsString()
  meetError?: string;
}
