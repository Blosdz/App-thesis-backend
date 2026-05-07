import { IsOptional, IsString } from 'class-validator';

export class UploadVoucherDto {
  @IsOptional()
  @IsString()
  codigoOperacion?: string;

  @IsOptional()
  @IsString()
  carpetaDriveId?: string;
}
