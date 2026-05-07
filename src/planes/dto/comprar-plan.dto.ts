import { IsUUID } from 'class-validator';

export class ComprarPlanDto {
  @IsUUID()
  planId: string;
}
