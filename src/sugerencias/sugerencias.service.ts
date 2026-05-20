import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { NotificationsService } from '../notifications/notifications.service';
import { ActualizarEstadoSugerenciaDto } from './dto/actualizar-estado-sugerencia.dto';
import { CrearSugerenciaDto } from './dto/crear-sugerencia.dto';
import { MarcarSugerenciaDto } from './dto/marcar-sugerencia.dto';

@Injectable()
export class SugerenciasService {
  constructor(
    private readonly databaseService: DatabaseService,
    private readonly notificationsService: NotificationsService,
  ) {}

  async crear(user: CurrentUser, dto: CrearSugerenciaDto) {
    if (user.rol !== 'asesor' && user.rol !== 'admin') {
      throw new ForbiddenException(
        'Esta operación requiere rol asesor o admin',
      );
    }

    const result = await this.databaseService.withTransaction(async (client) => {
      const tesis = await client.query<{
        id: string;
        estudiante_id: string;
        titulo: string | null;
      }>(
        `SELECT id, estudiante_id, titulo
         FROM "AT".tesis t
         WHERE t.id = $1
           AND t.eliminado_en IS NULL
           AND (
             EXISTS (
               SELECT 1
               FROM "AT".asesores_tesis at
               WHERE at.tesis_id = t.id
                 AND at.asesor_id = $2
                 AND at.activo = true
             )
             OR $3 = 'admin'
           )
         LIMIT 1`,
        [dto.tesisId, user.usuario_id, user.rol],
      );

      if (!tesis.rows[0]) {
        throw new ForbiddenException(
          'No tienes permiso para registrar sugerencias en esta tesis',
        );
      }

      const historial = await client.query(
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

      const validacion = await client.query(
        `INSERT INTO "AT".validaciones_sugerencia_asesor
           (historial_sugerencia_id, tesis_id, documento_tesis_id, estudiante_id, asesor_id, estado)
         VALUES ($1, $2, $3, $4, $5, 'pendiente')
         RETURNING *`,
        [
          historial.rows[0].id,
          dto.tesisId,
          dto.documentoTesisId ?? null,
          tesis.rows[0].estudiante_id,
          user.usuario_id,
        ],
      );

      await this.notificationsService.create(
        {
          userId: tesis.rows[0].estudiante_id,
          title: 'Nueva sugerencia',
          description: `Tienes una sugerencia para la tesis "${
            tesis.rows[0].titulo || 'Sin título'
          }".`,
          type: 'sugerencia_tesis',
          relatedId: historial.rows[0].id,
          path: '/student/my-thesis',
        },
        client,
      );

      return {
        ...historial.rows[0],
        estado_validacion: validacion.rows[0].estado,
        marcado_aplicado: validacion.rows[0].marcado_aplicado,
        comentario_estudiante: validacion.rows[0].comentario_estudiante,
        comentario_asesor: validacion.rows[0].comentario_asesor,
      };
    });

    return {
      ok: true,
      message: 'Sugerencia registrada correctamente',
      data: result,
    };
  }

  async listarPorTesis(tesisId: string) {
    const result = await this.databaseService.query(
      `SELECT 
         h.*,
         ts.nombre AS tipo_sugerencia_nombre,
         ts.nombre AS tipo_nombre,
         ts.codigo AS tipo_codigo,
         COALESCE(
           v.estado,
           CASE
             WHEN h.aplicado_por_estudiante THEN 'marcado_por_estudiante'
             ELSE 'pendiente'
           END
         ) AS estado_validacion,
         v.comentario_estudiante,
         v.comentario_asesor,
         COALESCE(v.marcado_aplicado, h.aplicado_por_estudiante, false) AS marcado_aplicado
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
    const historial = await this.databaseService.withTransaction(
      async (client) => {
        const historialResult = await client.query(
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
           RETURNING h.*, t.estudiante_id, t.titulo AS tesis_titulo`,
          [sugerenciaId, user.usuario_id, dto.aplicado, user.rol],
        );

        if (!historialResult.rows[0]) {
          throw new NotFoundException('Sugerencia no encontrada');
        }

        const sugerencia = historialResult.rows[0];

        await client.query(
          `INSERT INTO "AT".validaciones_sugerencia_asesor
             (historial_sugerencia_id, tesis_id, documento_tesis_id, estudiante_id, asesor_id, estado)
           SELECT $1, $2, $3, $4, $5, 'pendiente'
           WHERE NOT EXISTS (
             SELECT 1
             FROM "AT".validaciones_sugerencia_asesor
             WHERE historial_sugerencia_id = $1
           )`,
          [
            sugerenciaId,
            sugerencia.tesis_id,
            sugerencia.documento_tesis_id,
            sugerencia.estudiante_id,
            sugerencia.asesor_id,
          ],
        );

        await client.query(
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

        if (dto.aplicado) {
          const estudiante = await client.query<{ nombre: string | null }>(
            `SELECT NULLIF(trim(coalesce(nombres, '') || ' ' || coalesce(apellidos, '')), '') AS nombre
             FROM "AT".perfil_estudiante
             WHERE estudiante_id = $1
             LIMIT 1`,
            [sugerencia.estudiante_id],
          );
          const estudianteNombre = estudiante.rows[0]?.nombre || 'Un estudiante';

          await this.notificationsService.create(
            {
              userId: sugerencia.asesor_id,
              title: 'Sugerencia marcada como resuelta',
              description: `${estudianteNombre} marcó como resuelta una sugerencia de la tesis "${
                sugerencia.tesis_titulo || 'Sin título'
              }".`,
              type: 'sugerencia_resuelta_estudiante',
              relatedId: sugerenciaId,
              path: '/advisor/thesis',
            },
            client,
          );
        }

        return sugerencia;
      },
    );

    return {
      ok: true,
      message: 'Sugerencia actualizada correctamente',
      data: historial,
    };
  }

  async actualizarEstado(
    user: CurrentUser,
    sugerenciaId: string,
    dto: ActualizarEstadoSugerenciaDto,
  ) {
    const result = await this.databaseService.withTransaction(
      async (client) => {
        await client.query(
          `INSERT INTO "AT".validaciones_sugerencia_asesor
             (historial_sugerencia_id, tesis_id, documento_tesis_id, estudiante_id, asesor_id,
              marcado_aplicado, marcado_en, estado)
           SELECT
             h.id,
             h.tesis_id,
             h.documento_tesis_id,
             t.estudiante_id,
             h.asesor_id,
             COALESCE(h.aplicado_por_estudiante, false),
             h.aplicado_en,
             CASE
               WHEN h.aplicado_por_estudiante THEN 'marcado_por_estudiante'
               ELSE 'pendiente'
             END
           FROM "AT".historial_sugerencias_asesor h
           JOIN "AT".tesis t ON t.id = h.tesis_id
           WHERE h.id = $1
             AND (h.asesor_id = $2 OR $3::text = 'admin')
             AND NOT EXISTS (
               SELECT 1
               FROM "AT".validaciones_sugerencia_asesor v
               WHERE v.historial_sugerencia_id = h.id
             )`,
          [sugerenciaId, user.usuario_id, user.rol],
        );

        return client.query(
          `UPDATE "AT".validaciones_sugerencia_asesor v
           SET estado = $3::character varying,
               comentario_asesor = COALESCE($4, comentario_asesor),
               verificado_por_asesor = ($3::text = 'verificado'),
               verificado_en = CASE WHEN $3::text IN ('verificado', 'rechazado') THEN now() ELSE verificado_en END,
               actualizado_en = now()
           FROM "AT".historial_sugerencias_asesor h
           WHERE v.historial_sugerencia_id = h.id
             AND v.historial_sugerencia_id = $1
             AND (v.asesor_id = $2 OR $5::text = 'admin')
           RETURNING v.*`,
          [
            sugerenciaId,
            user.usuario_id,
            dto.estado,
            dto.comentario ?? null,
            user.rol,
          ],
        );
      },
    );
    if (!result.rows[0]) {
      throw new NotFoundException('Sugerencia no encontrada');
    }

    return {
      ok: true,
      message: 'Estado de sugerencia actualizado',
      data: result.rows[0],
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
