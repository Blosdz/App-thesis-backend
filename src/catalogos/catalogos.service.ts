import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class CatalogosService {
  constructor(private readonly databaseService: DatabaseService) {}

  async tiposTesis() {
    const result = await this.databaseService.query(
      `SELECT
         tt.id,
         tt.codigo,
         tt.nombre,
         tt.descripcion,
         dtf.uname AS default_doc_thesis_format,
         dtf.name AS default_doc_thesis_format_name,
         dtf.citation_type AS default_citation_type
       FROM "AT".tipos_tesis tt
       LEFT JOIN "AT".doc_thesis_formats dtf
         ON dtf.id = tt.default_doc_thesis_format_id
        AND dtf.active = true
       WHERE tt.activo = true
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
         dtf.uname AS default_doc_thesis_format,
         dtf.name AS default_doc_thesis_format_name,
         dtf.citation_type AS default_citation_type,
         ptp.precio_base,
         ptp.moneda
       FROM "AT".planes_tipos_tesis_precios ptp
       JOIN "AT".tipos_tesis tt ON tt.id = ptp.tipo_tesis_id
       LEFT JOIN "AT".doc_thesis_formats dtf
         ON dtf.id = tt.default_doc_thesis_format_id
        AND dtf.active = true
       WHERE ptp.plan_id = $1
         AND ptp.activo = true
         AND tt.activo = true
       ORDER BY tt.nombre ASC`,
      [planId],
    );
    return { ok: true, data: result.rows };
  }

  async docThesisFormats() {
    const result = await this.databaseService.query(
      `SELECT id, name, uname, citation_type, skeleton_json, word_settings_json
       FROM "AT".doc_thesis_formats
       WHERE active = true
       ORDER BY name ASC`,
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

  async especialidades() {
    const result = await this.databaseService.query(
      `SELECT id, nombre
       FROM "AT".especialidades
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
