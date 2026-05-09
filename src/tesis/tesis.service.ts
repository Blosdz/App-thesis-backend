import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { PlanesService } from '../planes/planes.service';
import { ActualizarEstadoTesisDto } from './dto/actualizar-estado-tesis.dto';
import { AsignarAsesorDto } from './dto/asignar-asesor.dto';
import { CrearTesisConPlanDto, CrearTesisDto } from './dto/crear-tesis.dto';

@Injectable()
export class TesisService {
  constructor(
    private readonly databaseService: DatabaseService,
    private readonly planesService: PlanesService,
  ) {}

  async crear(user: CurrentUser, dto: CrearTesisDto) {
    this.requireStudent(user);
    const result = await this.databaseService.query(
      `INSERT INTO "AT".tesis
         (estudiante_id, universidad_id, titulo, descripcion, estado)
       VALUES ($1, $2, $3, $4, 'borrador')
       RETURNING *`,
      [
        user.usuario_id,
        dto.universidadId ?? null,
        dto.titulo,
        dto.descripcion ?? null,
      ],
    );
    return {
      ok: true,
      message: 'Tesis creada correctamente',
      data: result.rows[0],
    };
  }

  async crearConPlan(user: CurrentUser, dto: CrearTesisConPlanDto) {
    this.requireStudent(user);

    const tesis = await this.databaseService.withTransaction(async (client) => {
      const cotizacion = await this.planesService.calcularCotizacion(client, {
        planId: dto.planId,
        tipoTesisId: dto.tipoTesisId,
        nivelAcademico: dto.nivelAcademico,
        requiereAnalisisEstadistico: dto.requiereAnalisisEstadistico,
      });

      const tesisResult = await client.query(
        `INSERT INTO "AT".tesis
           (estudiante_id, universidad_id, titulo, descripcion, estado, tipo_tesis_id, plan_id,
            programa_id, nivel_academico, cantidad_variables, requiere_estadistica,
            es_arquitectura_diseno, precio_base, precio_ajustes, precio_total, moneda,
            requiere_analisis_estadistico, porcentaje_nivel, monto_ajuste_nivel,
            descuento_analisis_estadistico)
         VALUES
           ($1, $2, $3, $4, 'pendiente_pago', $5, $6, $7, $8, $9, $10, $11,
            $12, $13, $14, $15, $16, $17, $18, $19)
         RETURNING *`,
        [
          user.usuario_id,
          dto.universidadId ?? null,
          dto.titulo,
          dto.descripcion ?? null,
          dto.tipoTesisId,
          dto.planId,
          dto.programaId ?? null,
          dto.nivelAcademico,
          dto.cantidadVariables ?? 1,
          dto.requiereAnalisisEstadistico ?? true,
          dto.esArquitecturaDiseno ?? false,
          cotizacion.precio_base,
          cotizacion.ajuste_nivel,
          cotizacion.total_final,
          cotizacion.moneda,
          dto.requiereAnalisisEstadistico ?? true,
          cotizacion.porcentaje_nivel,
          cotizacion.ajuste_nivel,
          cotizacion.descuento_analisis_estadistico,
        ],
      );

      await client.query(
        `INSERT INTO "AT".cotizaciones_tesis
           (tesis_id, estudiante_id, plan_id, tipo_investigacion, nivel_academico,
            precio_base, ajuste_nivel, subtotal, total_ajustes, total_final, moneda,
            estado, metadata)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 0, $9, $10, 'borrador', $11)`,
        [
          tesisResult.rows[0].id,
          user.usuario_id,
          dto.planId,
          String(cotizacion.tipo_tesis_nombre),
          dto.nivelAcademico,
          cotizacion.precio_base,
          cotizacion.ajuste_nivel,
          Number(cotizacion.precio_base) + Number(cotizacion.ajuste_nivel),
          cotizacion.total_final,
          cotizacion.moneda,
          cotizacion,
        ],
      );

      return { ...tesisResult.rows[0], cotizacion };
    });

    return {
      ok: true,
      message: 'Tesis con plan creada correctamente',
      data: tesis,
    };
  }

  async misTesis(user: CurrentUser) {
    const result = await this.databaseService.query(
      `SELECT t.*, tt.nombre AS tipo_tesis_nombre, p.nombre AS plan_nombre
       FROM "AT".tesis t
       LEFT JOIN "AT".tipos_tesis tt ON tt.id = t.tipo_tesis_id
       LEFT JOIN "AT".planes p ON p.id = t.plan_id
       WHERE t.estudiante_id = $1
         AND t.eliminado_en IS NULL
       ORDER BY t.creado_en DESC`,
      [user.usuario_id],
    );
    return { ok: true, data: result.rows };
  }

  async misTesisConAsesores(user: CurrentUser) {
    const result = await this.databaseService.query(
      `SELECT
         t.*,
         COALESCE(
           jsonb_agg(
             jsonb_build_object(
               'asesor_id', at.asesor_id,
               'rol', at.rol,
               'nombre_mostrar', ppa.nombre_mostrar,
               'foto_url', ppa.foto_url
             )
           ) FILTER (WHERE at.id IS NOT NULL),
           '[]'::jsonb
         ) AS asesores
       FROM "AT".tesis t
       LEFT JOIN "AT".asesores_tesis at ON at.tesis_id = t.id AND at.activo = true
       LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = at.asesor_id
       WHERE t.estudiante_id = $1
         AND t.eliminado_en IS NULL
       GROUP BY t.id
       ORDER BY t.creado_en DESC`,
      [user.usuario_id],
    );
    return { ok: true, data: result.rows };
  }

  async asignadasAsesor(user: CurrentUser) {
    if (user.rol !== 'asesor') {
      throw new ForbiddenException('Esta operación requiere rol asesor');
    }
    const result = await this.databaseService.query(
      `SELECT t.*, pe.nombres, pe.apellidos, at.rol AS rol_asesor
       FROM "AT".asesores_tesis at
       JOIN "AT".tesis t ON t.id = at.tesis_id
       LEFT JOIN "AT".perfil_estudiante pe ON pe.estudiante_id = t.estudiante_id
       WHERE at.asesor_id = $1
         AND at.activo = true
         AND t.eliminado_en IS NULL
       ORDER BY t.creado_en DESC`,
      [user.usuario_id],
    );
    return { ok: true, data: result.rows };
  }

  async obtenerDetalle(user: CurrentUser, tesisId: string) {
    const result = await this.databaseService.query(
      `SELECT t.*
       FROM "AT".tesis t
       WHERE t.id = $1
         AND t.eliminado_en IS NULL
         AND (
           t.estudiante_id = $2
           OR EXISTS (
             SELECT 1 FROM "AT".asesores_tesis at
             WHERE at.tesis_id = t.id AND at.asesor_id = $2 AND at.activo = true
           )
           OR $3 = 'admin'
         )
       LIMIT 1`,
      [tesisId, user.usuario_id, user.rol],
    );

    if (!result.rows[0]) {
      throw new NotFoundException('Tesis no encontrada');
    }

    return { ok: true, data: result.rows[0] };
  }

  async actualizarEstado(
    user: CurrentUser,
    tesisId: string,
    dto: ActualizarEstadoTesisDto,
  ) {
    const result = await this.databaseService.query(
      `UPDATE "AT".tesis
       SET estado = $3, actualizado_en = now()
       WHERE id = $1
         AND eliminado_en IS NULL
         AND (estudiante_id = $2 OR $4 = 'admin')
       RETURNING *`,
      [tesisId, user.usuario_id, dto.estado, user.rol],
    );

    if (!result.rows[0]) {
      throw new NotFoundException('Tesis no encontrada');
    }

    return {
      ok: true,
      message: 'Estado actualizado correctamente',
      data: result.rows[0],
    };
  }

  async asignarAsesor(
    user: CurrentUser,
    tesisId: string,
    dto: AsignarAsesorDto,
  ) {
    this.requireStudent(user);

    const asignacion = await this.databaseService.withTransaction(
      async (client) => {
        const tesis = await client.query<{ id: string; estudiante_id: string }>(
          `SELECT id, estudiante_id
         FROM "AT".tesis
         WHERE id = $1 AND estudiante_id = $2 AND eliminado_en IS NULL
         LIMIT 1`,
          [tesisId, user.usuario_id],
        );

        if (!tesis.rows[0]) {
          throw new NotFoundException('Tesis no encontrada');
        }

        const relacion = await client.query<{ id: string }>(
          `SELECT id
         FROM "AT".relaciones_asesor_estudiante
         WHERE asesor_id = $1
           AND estudiante_id = $2
           AND estado IN ('pendiente', 'activo')
         ORDER BY creado_en DESC
         LIMIT 1`,
          [dto.asesorId, user.usuario_id],
        );

        const relacionId =
          relacion.rows[0]?.id ??
          (
            await client.query<{ id: string }>(
              `INSERT INTO "AT".relaciones_asesor_estudiante
               (asesor_id, estudiante_id, estado)
             VALUES ($1, $2, 'pendiente')
             RETURNING id`,
              [dto.asesorId, user.usuario_id],
            )
          ).rows[0].id;

        const existing = await client.query(
          `SELECT id
         FROM "AT".asesores_tesis
         WHERE asesor_id = $1 AND tesis_id = $2 AND activo = true
         LIMIT 1`,
          [dto.asesorId, tesisId],
        );

        if (existing.rows[0]) {
          return existing.rows[0];
        }

        const inserted = await client.query(
          `INSERT INTO "AT".asesores_tesis
           (asesor_id, tesis_id, activo, rol, relacion_id)
         VALUES ($1, $2, true, $3, $4)
         RETURNING *`,
          [dto.asesorId, tesisId, dto.rol ?? 'principal', relacionId],
        );
        return inserted.rows[0];
      },
    );

    return {
      ok: true,
      message: 'Asesor asignado correctamente',
      data: asignacion,
    };
  }

  private requireStudent(user: CurrentUser) {
    if (user.rol !== 'estudiante') {
      throw new ForbiddenException('Esta operación requiere rol estudiante');
    }
  }
}
