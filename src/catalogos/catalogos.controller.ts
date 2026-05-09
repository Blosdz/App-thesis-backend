import { Controller, Get, Param, Query } from '@nestjs/common';
import { CatalogosService } from './catalogos.service';

@Controller('catalogos')
export class CatalogosController {
  constructor(private readonly catalogosService: CatalogosService) {}

  @Get('tipos-tesis')
  tiposTesis() {
    return this.catalogosService.tiposTesis();
  }

  @Get('tipos-tesis/por-plan/:planId')
  tiposTesisPorPlan(@Param('planId') planId: string) {
    return this.catalogosService.tiposTesisPorPlan(planId);
  }

  @Get('universidades')
  universidades() {
    return this.catalogosService.universidades();
  }

  @Get('programas')
  programas(@Query('universidadId') universidadId?: string) {
    return this.catalogosService.programas(universidadId);
  }
}
