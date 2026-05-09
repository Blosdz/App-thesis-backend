import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class CatalogosService {
  constructor(private readonly databaseService: DatabaseService) {}

  async tiposTesis() {
    const result = await this.databaseService.query(
      `SELECT id, codigo, nombre, descripcion
       FROM "AT".tipos_tesis
       WHERE activo = true
       ORDER BY nombre ASC`,
    );
    return { ok: true, data: result.rows };
  }

  async tiposTesisPorPlan(planId: string) {
    const result = await this.databaseService.query(
      `SELECT
         tt.id,
         tt.codigo,
         tt.nombre,
         tt.descripcion,
         ptp.precio_base,
         ptp.moneda
       FROM "AT".planes_tipos_tesis_precios ptp
       JOIN "AT".tipos_tesis tt ON tt.id = ptp.tipo_tesis_id
       WHERE ptp.plan_id = $1
         AND ptp.activo = true
         AND tt.activo = true
       ORDER BY tt.nombre ASC`,
      [planId],
    );
    return { ok: true, data: result.rows };
  }

  async universidades() {
    const result = await this.databaseService.query(
      `SELECT id, nombre, ubicacion, pais
       FROM "AT".universidades
       ORDER BY nombre ASC`,
    );
    return { ok: true, data: result.rows };
  }

  async programas(universidadId?: string) {
    const params = universidadId ? [universidadId] : [];
    const result = await this.databaseService.query(
      `SELECT p.*, e.nombre AS especialidad_nombre
       FROM "AT".programas p
       LEFT JOIN "AT".especialidades e ON e.id = p.especialidad_id
       WHERE ($1::uuid IS NULL OR p.universidad_id = $1::uuid)
       ORDER BY p.nivel ASC, p.nombre ASC`,
      [params[0] ?? null],
    );
    return { ok: true, data: result.rows };
  }
}
