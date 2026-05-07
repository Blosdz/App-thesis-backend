import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class AdminService {
  constructor(private readonly databaseService: DatabaseService) {}

  async listarUsuarios() {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".admin_listar_usuarios()',
    );

    return { ok: true, data: result.rows };
  }
}
