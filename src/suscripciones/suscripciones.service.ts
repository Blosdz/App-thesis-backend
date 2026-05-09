import { Injectable } from '@nestjs/common';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class SuscripcionesService {
  constructor(private readonly databaseService: DatabaseService) {}

  async miSuscripcion(user: CurrentUser) {
    const result = await this.databaseService.query(
      `SELECT se.*, p.nombre AS plan_nombre, p.caracteristicas
       FROM "AT".suscripciones_estudiante se
       JOIN "AT".planes p ON p.id = se.plan_id
       WHERE se.estudiante_id = $1
         AND se.estado = 'activo'
         AND (se.expira_en IS NULL OR se.expira_en > now())
       ORDER BY se.iniciado_en DESC
       LIMIT 1`,
      [user.usuario_id],
    );
    return { ok: true, data: result.rows[0] ?? null };
  }

  async suscripcionEstudiante(estudianteId: string) {
    const result = await this.databaseService.query(
      `SELECT se.*, p.nombre AS plan_nombre
       FROM "AT".suscripciones_estudiante se
       JOIN "AT".planes p ON p.id = se.plan_id
       WHERE se.estudiante_id = $1
       ORDER BY se.iniciado_en DESC`,
      [estudianteId],
    );
    return { ok: true, data: result.rows };
  }

  async beneficioDisponible(estudianteId: string, codigo: string) {
    const result = await this.databaseService.query(
      `SELECT sbc.*, b.codigo, b.nombre, b.descripcion
       FROM "AT".suscripcion_beneficios_consumo sbc
       JOIN "AT".beneficios_plan_catalogo b ON b.id = sbc.beneficio_id
       JOIN "AT".suscripciones_estudiante se ON se.id = sbc.suscripcion_id
       WHERE se.estudiante_id = $1
         AND se.estado = 'activo'
         AND b.codigo = $2
       ORDER BY se.iniciado_en DESC
       LIMIT 1`,
      [estudianteId, codigo],
    );
    return { ok: true, data: result.rows[0] ?? null };
  }

  async consumirBeneficio(beneficioConsumoId: string) {
    const result = await this.databaseService.query(
      `UPDATE "AT".suscripcion_beneficios_consumo
       SET cantidad_usada = cantidad_usada + 1,
           actualizado_en = now()
       WHERE id = $1
         AND cantidad_disponible > 0
       RETURNING *`,
      [beneficioConsumoId],
    );
    return {
      ok: true,
      message:
        result.rowCount === 0
          ? 'No hay beneficio disponible para consumir'
          : 'Beneficio consumido correctamente',
      data: result.rows[0] ?? null,
    };
  }
}
