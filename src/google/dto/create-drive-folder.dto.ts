import { IsOptional, IsString } from 'class-validator';

export class CreateDriveFolderDto {
  @IsOptional()
  @IsString()
  nombre?: string;

  @IsOptional()
  @IsString()
  parentFolderId?: string;
}
