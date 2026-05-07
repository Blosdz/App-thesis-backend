import { IsISO8601, IsOptional, IsString } from 'class-validator';

export class CreateMeetDto {
  @IsString()
  summary: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsISO8601()
  start: string;

  @IsISO8601()
  end: string;
}
