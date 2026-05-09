import { Body, Controller, Post } from '@nestjs/common';
import { RegistrarLeadDto } from './dto/registrar-lead.dto';
import { LeadsService } from './leads.service';

@Controller('leads')
export class LeadsController {
  constructor(private readonly leadsService: LeadsService) {}

  @Post('estudiante')
  registrarEstudiante(@Body() dto: RegistrarLeadDto) {
    return this.leadsService.registrarEstudiante(dto);
  }
}
