import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class CatalogosService {
  constructor(private readonly databaseService: DatabaseService) {}

  async listarUniversidades() {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_catalogo_universidades()',
    );

    return { ok: true, data: result.rows };
  }
}
