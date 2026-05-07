import { Injectable } from '@nestjs/common';
import { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class SuscripcionesService {
  constructor(private readonly databaseService: DatabaseService) {}

  async obtenerActual(user: CurrentUser) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_suscripcion_obtener_actual($1)',
      [user.usuario_id],
    );

    return { ok: true, data: result.rows[0] ?? null };
  }
}
