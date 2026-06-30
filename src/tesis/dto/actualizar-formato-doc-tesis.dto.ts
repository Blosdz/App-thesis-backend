import { IsString, MaxLength } from 'class-validator';

export class ActualizarFormatoDocTesisDto {
  @IsString()
  @MaxLength(60)
  docThesisFormat!: string;
}
