import { Controller, Get } from '@nestjs/common';
import { CatalogosService } from './catalogos.service';

@Controller('catalogos')
export class CatalogosController {
  constructor(private readonly catalogosService: CatalogosService) {}

  @Get('universidades')
  listarUniversidades() {
    return this.catalogosService.listarUniversidades();
  }
}
