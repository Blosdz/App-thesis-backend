import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { ActualizarEstadoSugerenciaDto } from './dto/actualizar-estado-sugerencia.dto';
import { CrearSugerenciaDto } from './dto/crear-sugerencia.dto';
import { MarcarSugerenciaDto } from './dto/marcar-sugerencia.dto';

@Injectable()
export class SugerenciasService {
  constructor(private readonly databaseService: DatabaseService) {}

  async crear(user: CurrentUser, dto: CrearSugerenciaDto) {
    if (user.rol !== 'asesor' && user.rol !== 'admin') {
      throw new ForbiddenException(
        'Esta operación requiere rol asesor o admin',
      );
    }
    const result = await this.databaseService.query(
      `INSERT INTO "AT".historial_sugerencias_asesor
         (tesis_id, asesor_id, documento_tesis_id, sugerencia, detalle, tipo_sugerencia_id)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [
        dto.tesisId,
        user.usuario_id,
        dto.documentoTesisId ?? null,
        dto.sugerencia,
        dto.detalle ?? null,
        dto.tipoSugerenciaId ?? null,
      ],
    );
    return {
      ok: true,
      message: 'Sugerencia registrada correctamente',
      data: result.rows[0],
    };
  }

  async listarPorTesis(tesisId: string) {
    const result = await this.databaseService.query(
      `SELECT 
         h.*,
         ts.nombre AS tipo_sugerencia_nombre,
         v.estado AS estado_validacion,
         v.comentario_estudiante,
         v.comentario_asesor,
         v.marcado_aplicado
       FROM "AT".historial_sugerencias_asesor h
       LEFT JOIN "AT".tipos_sugerencia_asesor ts ON ts.id = h.tipo_sugerencia_id
       LEFT JOIN "AT".validaciones_sugerencia_asesor v ON v.historial_sugerencia_id = h.id
       WHERE h.tesis_id = $1
       ORDER BY h.creado_en DESC`,
      [tesisId],
    );
    return { ok: true, data: result.rows };
  }

  async tipos() {
    const result = await this.databaseService.query(
      `SELECT *
       FROM "AT".tipos_sugerencia_asesor
       WHERE activo = true
       ORDER BY nombre ASC`,
    );
    return { ok: true, data: result.rows };
  }

  async marcarAplicada(
    user: CurrentUser,
    sugerenciaId: string,
    dto: MarcarSugerenciaDto,
  ) {
    // Primero actualizar historial_sugerencias_asesor
    const historialResult = await this.databaseService.query(
      `UPDATE "AT".historial_sugerencias_asesor h
       SET aplicado_por_estudiante = $3,
           aplicado = $3,
           aplicado_por = $2,
           aplicado_en = CASE WHEN $3 THEN now() ELSE NULL END,
           actualizado_en = now()
       FROM "AT".tesis t
       WHERE h.tesis_id = t.id
         AND h.id = $1
         AND (t.estudiante_id = $2 OR $4 = 'admin')
       RETURNING h.*`,
      [sugerenciaId, user.usuario_id, dto.aplicado, user.rol],
    );

    if (!historialResult.rows[0]) {
      throw new NotFoundException('Sugerencia no encontrada');
    }

    // Ahora actualizar validaciones_sugerencia_asesor
    await this.databaseService.query(
      `UPDATE "AT".validaciones_sugerencia_asesor v
       SET 
         estado = CASE WHEN $2 THEN 'marcado_por_estudiante' ELSE 'pendiente' END,
         comentario_estudiante = $3,
         marcado_aplicado = $2,
         marcado_en = CASE WHEN $2 THEN now() ELSE NULL END,
         actualizado_en = now()
       WHERE historial_sugerencia_id = $1`,
      [sugerenciaId, dto.aplicado, dto.comentario ?? null],
    );

    return {
      ok: true,
      message: 'Sugerencia actualizada correctamente',
      data: historialResult.rows[0],
    };
  }

  async actualizarEstado(
    user: CurrentUser,
    sugerenciaId: string,
    dto: ActualizarEstadoSugerenciaDto,
  ) {
    const result = await this.databaseService.query(
      `UPDATE "AT".validaciones_sugerencia_asesor
       SET estado = $3,
           comentario_asesor = COALESCE($4, comentario_asesor),
           verificado_por_asesor = ($3 = 'verificado'),
           verificado_en = CASE WHEN $3 IN ('verificado', 'rechazado') THEN now() ELSE verificado_en END,
           actualizado_en = now()
       WHERE historial_sugerencia_id = $1
         AND (asesor_id = $2 OR $5 = 'admin')
       RETURNING *`,
      [
        sugerenciaId,
        user.usuario_id,
        dto.estado,
        dto.comentario ?? null,
        user.rol,
      ],
    );
    return {
      ok: true,
      message: 'Estado de sugerencia actualizado',
      data: result.rows[0] ?? null,
    };
  }

  async log(sugerenciaId: string) {
    const result = await this.databaseService.query(
      `SELECT *
       FROM "AT".vw_log_validacion_sugerencia
       WHERE historial_sugerencia_id = $1
       ORDER BY creado_en ASC`,
      [sugerenciaId],
    );
    return { ok: true, data: result.rows };
  }
}
