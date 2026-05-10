import { IsOptional, IsString, Length, MaxLength } from 'class-validator';

export class VincularPorSlugDto {
  @IsString()
  @Length(3, 150)
  slug: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  mensaje?: string;
}
