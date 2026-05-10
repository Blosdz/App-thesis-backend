import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { BloquesDisponiblesDto } from './dto/bloques-disponibles.dto';
import { CambiarEstadoRelacionDto } from './dto/cambiar-estado-relacion.dto';
import { CrearEspacioLibreDto } from './dto/crear-espacio-libre.dto';
import { ListarAsesoresQueryDto } from './dto/listar-asesores-query.dto';
import { VincularAsesorDto } from './dto/vincular-asesor.dto';
import { VincularPorCodigoDto } from './dto/vincular-por-codigo.dto';
import { VincularPorSlugDto } from './dto/vincular-por-slug.dto';

@Injectable()
export class AsesoresService {
  constructor(private readonly databaseService: DatabaseService) {}

  async obtenerAsesores(query: ListarAsesoresQueryDto = {}) {
    return this.listarAsesores(query);
  }

  async listarAsesores(query: ListarAsesoresQueryDto = {}) {
    const values: unknown[] = [];
    const conditions = [`u.rol = 'asesor'`];

    if (query.buscar?.trim()) {
      values.push(`%${query.buscar.trim()}%`);
      conditions.push(`
        (
          ppa.nombre_mostrar ILIKE $${values.length}
          OR ppa.biografia ILIKE $${values.length}
          OR ppa.carrera ILIKE $${values.length}
          OR uni.nombre ILIKE $${values.length}
          OR e.nombre ILIKE $${values.length}
          OR cpa.codigo_publico ILIKE $${values.length}
        )
      `);
    }

    if (query.universidadId) {
      values.push(query.universidadId);
      conditions.push(`ppa.universidad_id = $${values.length}`);
    }

    if (query.especialidadId) {
      values.push(query.especialidadId);
      conditions.push(`ppa.especialidad_id = $${values.length}`);
    }

    if (query.carrera?.trim()) {
      values.push(`%${query.carrera.trim()}%`);
      conditions.push(`ppa.carrera ILIKE $${values.length}`);
    }

    if (query.nivelAcademico?.trim()) {
      values.push(query.nivelAcademico.trim());
      conditions.push(`ppa.nivel_academico = $${values.length}`);
    }

    const result = await this.databaseService.query(
      `SELECT
         u.id AS asesor_id,
         u.id AS "asesorId",
         ppa.id AS perfil_id,
         ppa.id AS "perfilId",
         ppa.nombre_mostrar,
         ppa.nombre_mostrar AS "nombreMostrar",
         ppa.slug,
         ppa.email_publico,
         ppa.email_publico AS "emailPublico",
         ppa.biografia,
         ppa.foto_url,
         ppa.foto_url AS "fotoUrl",
         ppa.carrera,
         ppa.nivel_academico,
         ppa.nivel_academico AS "nivelAcademico",
         ppa.universidad_id,
         ppa.universidad_id AS "universidadId",
         ppa.especialidad_id,
         ppa.especialidad_id AS "especialidadId",
         e.nombre AS especialidad_nombre,
         e.nombre AS "especialidadNombre",
         uni.nombre AS universidad_nombre,
         uni.nombre AS "universidadNombre",
         cpa.codigo_publico,
         cpa.codigo_publico AS "codigoPublico"
       FROM "AT".usuarios u
       INNER JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = u.id
       LEFT JOIN "AT".especialidades e ON e.id = ppa.especialidad_id
       LEFT JOIN "AT".universidades uni ON uni.id = ppa.universidad_id
       LEFT JOIN LATERAL (
         SELECT codigo_publico
         FROM "AT".codigos_publicos_asesor
         WHERE asesor_id = u.id
           AND activo = true
           AND (expira_en IS NULL OR expira_en > now())
         ORDER BY creado_en DESC
         LIMIT 1
       ) cpa ON true
       WHERE ${conditions.join(' AND ')}
       ORDER BY ppa.nombre_mostrar ASC NULLS LAST, u.creado_en DESC`,
      values,
    );
    return { ok: true, total: result.rowCount, data: result.rows };
  }

  async obtenerMisAsesores(user: CurrentUser) {
    if (user.rol !== 'estudiante') {
      throw new ForbiddenException('Esta operación requiere rol estudiante');
    }
    const result = await this.databaseService.query(
      `SELECT
         r.*,
         ppa.nombre_mostrar,
         ppa.slug,
         ppa.foto_url,
         ppa.biografia
       FROM "AT".relaciones_asesor_estudiante r
       JOIN "AT".usuarios u ON u.id = r.asesor_id
       LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = r.asesor_id
       WHERE r.estudiante_id = $1
       ORDER BY r.creado_en DESC`,
      [user.usuario_id],
    );
    return { ok: true, data: result.rows };
  }

  async obtenerEstudiantesAsesor(user: CurrentUser) {
    if (user.rol !== 'asesor') {
      throw new ForbiddenException('Esta operación requiere rol asesor');
    }
    const result = await this.databaseService.query(
      `SELECT
         r.*,
         pe.nombres,
         pe.apellidos,
         pe.carrera,
         uni.nombre AS universidad_nombre
       FROM "AT".relaciones_asesor_estudiante r
       JOIN "AT".usuarios u ON u.id = r.estudiante_id
       LEFT JOIN "AT".perfil_estudiante pe ON pe.estudiante_id = r.estudiante_id
       LEFT JOIN "AT".universidades uni ON uni.id = pe.universidad_id
       WHERE r.asesor_id = $1
       ORDER BY r.creado_en DESC`,
      [user.usuario_id],
    );
    return { ok: true, data: result.rows };
  }

  async obtenerPerfilPublico(valor: string) {
    const result = await this.databaseService.query(
      `SELECT ppa.*, u.id AS asesor_id
       FROM "AT".perfil_publico_asesor ppa
       JOIN "AT".usuarios u ON u.id = ppa.asesor_id
       WHERE ppa.asesor_id::text = $1 OR ppa.slug = $1
       LIMIT 1`,
      [valor],
    );

    if (!result.rows[0]) {
      throw new NotFoundException('Perfil de asesor no encontrado');
    }

    return { ok: true, data: result.rows[0] };
  }

  async generarCodigoPublico(user: CurrentUser) {
    if (user.rol !== 'asesor') {
      throw new ForbiddenException('Esta operación requiere rol asesor');
    }

    const codigo = randomUUID().replace(/-/g, '').slice(0, 10).toUpperCase();
    const result = await this.databaseService.withTransaction(
      async (client) => {
        await client.query(
          `UPDATE "AT".codigos_publicos_asesor
         SET activo = false, actualizado_en = now()
         WHERE asesor_id = $1 AND activo = true`,
          [user.usuario_id],
        );
        const inserted = await client.query(
          `INSERT INTO "AT".codigos_publicos_asesor (asesor_id, codigo_publico)
         VALUES ($1, $2)
         RETURNING *`,
          [user.usuario_id, codigo],
        );
        return inserted.rows[0];
      },
    );

    return {
      ok: true,
      message: 'Código público generado correctamente',
      data: result,
    };
  }

  async obtenerMiCodigoPublico(user: CurrentUser) {
    if (user.rol !== 'asesor') {
      throw new ForbiddenException('Esta operación requiere rol asesor');
    }
    const result = await this.databaseService.query(
      `SELECT *
       FROM "AT".codigos_publicos_asesor
       WHERE asesor_id = $1 AND activo = true
       ORDER BY creado_en DESC
       LIMIT 1`,
      [user.usuario_id],
    );
    return { ok: true, data: result.rows[0] ?? null };
  }

  async cambiarEstadoRelacion(
    user: CurrentUser,
    relacionId: string,
    dto: CambiarEstadoRelacionDto,
  ) {
    const result = await this.databaseService.query(
      `UPDATE "AT".relaciones_asesor_estudiante
       SET estado = $3, actualizado_en = now()
       WHERE id = $1
         AND (asesor_id = $2 OR estudiante_id = $2 OR $4 = 'admin')
       RETURNING *`,
      [relacionId, user.usuario_id, dto.estado, user.rol],
    );

    if (!result.rows[0]) {
      throw new NotFoundException('Relación no encontrada');
    }

    return {
      ok: true,
      message: 'Estado de relación actualizado correctamente',
      data: result.rows[0],
    };
  }

  async vincularPorSlug(
    user: CurrentUser,
    slug: string,
    dto: VincularAsesorDto,
  ) {
    this.requireStudent(user);
    const asesor = await this.databaseService.query<{ asesor_id: string }>(
      `SELECT asesor_id
       FROM "AT".perfil_publico_asesor ppa
       JOIN "AT".usuarios u ON u.id = ppa.asesor_id
       WHERE ppa.slug = $1
         AND u.rol = 'asesor'
       LIMIT 1`,
      [slug],
    );

    if (!asesor.rows[0]) {
      throw new NotFoundException('Asesor no encontrado');
    }

    return this.crearOVolverRelacion(user, asesor.rows[0].asesor_id, null, dto);
  }

  async vincularPorCodigo(
    user: CurrentUser,
    codigo: string,
    dto: VincularAsesorDto,
  ) {
    this.requireStudent(user);
    const codigoResult = await this.databaseService.query<{
      id: string;
      asesor_id: string;
    }>(
      `SELECT id, asesor_id
       FROM "AT".codigos_publicos_asesor cpa
       JOIN "AT".usuarios u ON u.id = cpa.asesor_id
       WHERE upper(cpa.codigo_publico) = upper($1)
         AND cpa.activo = true
         AND (cpa.expira_en IS NULL OR cpa.expira_en > now())
         AND u.rol = 'asesor'
       ORDER BY cpa.creado_en DESC
       LIMIT 1`,
      [codigo],
    );

    if (!codigoResult.rows[0]) {
      throw new NotFoundException('Código de asesor no encontrado');
    }

    return this.crearOVolverRelacion(
      user,
      codigoResult.rows[0].asesor_id,
      codigoResult.rows[0].id,
      dto,
    );
  }

  async vincularPorSlugBody(user: CurrentUser, dto: VincularPorSlugDto) {
    return this.vincularPorSlug(user, dto.slug, { mensaje: dto.mensaje });
  }

  async vincularPorCodigoBody(user: CurrentUser, dto: VincularPorCodigoDto) {
    return this.vincularPorCodigo(user, dto.codigo, { mensaje: dto.mensaje });
  }

  async crearEspacioLibre(user: CurrentUser, dto: CrearEspacioLibreDto) {
    const asesorId = dto.asesorId ?? user.usuario_id;
    if (user.rol !== 'asesor' && user.rol !== 'admin') {
      throw new ForbiddenException(
        'Esta operación requiere rol asesor o admin',
      );
    }
    if (user.rol === 'asesor' && asesorId !== user.usuario_id) {
      throw new ForbiddenException(
        'No puedes crear disponibilidad para otro asesor',
      );
    }

    const inicio = new Date(dto.inicio);
    const fin = new Date(dto.fin);
    const recurrente = dto.recurrente ?? false;
    const duracionBloqueMinutos = dto.duracionBloqueMinutos ?? 30;

    if (Number.isNaN(inicio.getTime()) || Number.isNaN(fin.getTime())) {
      throw new BadRequestException('Fechas inválidas');
    }

    if (fin <= inicio) {
      throw new BadRequestException(
        'La fecha fin debe ser mayor a la fecha inicio',
      );
    }

    if (recurrente && dto.diaSemana === undefined) {
      throw new BadRequestException(
        'Si la disponibilidad es recurrente debe indicar diaSemana',
      );
    }

    const result = await this.databaseService.query(
      `INSERT INTO "AT".disponibilidad_asesor
         (asesor_id, inicio, fin, usa_bloques, duracion_bloque_minutos, recurrente,
          dia_semana, fecha_inicio, fecha_fin)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [
        asesorId,
        dto.inicio,
        dto.fin,
        dto.usaBloques ?? true,
        duracionBloqueMinutos,
        recurrente,
        dto.diaSemana ?? null,
        dto.fechaInicio ?? null,
        dto.fechaFin ?? null,
      ],
    );

    const row = result.rows[0];

    return {
      ok: true,
      disponibilidadId: row.id,
      asesorId: row.asesor_id,
      inicio: row.inicio,
      fin: row.fin,
      usaBloques: row.usa_bloques,
      duracionBloqueMinutos: row.duracion_bloque_minutos,
      recurrente: row.recurrente,
      diaSemana: row.dia_semana,
      fechaInicio: row.fecha_inicio,
      fechaFin: row.fecha_fin,
      disponible: row.disponible,
      activo: row.activo,
      mensaje: 'Espacio libre creado correctamente',
      message: 'Espacio libre creado correctamente',
      data: row,
    };
  }

  async misEspaciosLibres(user: CurrentUser) {
    if (user.rol !== 'asesor') {
      throw new ForbiddenException('Esta operación requiere rol asesor');
    }
    const result = await this.databaseService.query(
      `SELECT *
       FROM "AT".disponibilidad_asesor
       WHERE asesor_id = $1 AND activo = true
       ORDER BY inicio ASC`,
      [user.usuario_id],
    );
    return { ok: true, data: result.rows };
  }

  async desactivarEspacio(user: CurrentUser, disponibilidadId: string) {
    const result = await this.databaseService.query(
      `UPDATE "AT".disponibilidad_asesor
       SET activo = false, disponible = false, actualizado_en = now()
       WHERE id = $1 AND (asesor_id = $2 OR $3 = 'admin')
       RETURNING *`,
      [disponibilidadId, user.usuario_id, user.rol],
    );

    if (!result.rows[0]) {
      throw new NotFoundException('Disponibilidad no encontrada');
    }

    return {
      ok: true,
      message: 'Espacio libre desactivado correctamente',
      data: result.rows[0],
    };
  }

  async bloquesDisponibles(asesorId: string, dto: BloquesDisponiblesDto) {
    const result = await this.databaseService.query(
      `WITH bloques AS (
         SELECT
           da.id AS disponibilidad_id,
           bloque.inicio AS inicio,
           bloque.inicio + make_interval(mins => da.duracion_bloque_minutos) AS fin,
           da.duracion_bloque_minutos
         FROM "AT".disponibilidad_asesor da
         CROSS JOIN LATERAL generate_series(
           GREATEST(da.inicio, $2::timestamptz),
           LEAST(da.fin, $3::timestamptz) - make_interval(mins => da.duracion_bloque_minutos),
           make_interval(mins => da.duracion_bloque_minutos)
         ) AS bloque(inicio)
         WHERE da.asesor_id = $1
           AND da.activo = true
           AND da.disponible = true
           AND da.recurrente = false
           AND da.usa_bloques = true
           AND da.fin > $2::timestamptz
           AND da.inicio < $3::timestamptz

         UNION ALL

         SELECT
           da.id AS disponibilidad_id,
           da.inicio,
           da.fin,
           CEIL(EXTRACT(EPOCH FROM (da.fin - da.inicio)) / 60)::int
             AS duracion_bloque_minutos
         FROM "AT".disponibilidad_asesor da
         WHERE da.asesor_id = $1
           AND da.activo = true
           AND da.disponible = true
           AND da.recurrente = false
           AND da.usa_bloques = false
           AND da.fin > $2::timestamptz
           AND da.inicio < $3::timestamptz

         UNION ALL

         SELECT
           da.id AS disponibilidad_id,
           bloque.inicio AS inicio,
           bloque.inicio + make_interval(mins => da.duracion_bloque_minutos) AS fin,
           da.duracion_bloque_minutos
         FROM "AT".disponibilidad_asesor da
         CROSS JOIN LATERAL generate_series(
           GREATEST(
             ($2::timestamptz AT TIME ZONE 'America/Lima')::date,
             COALESCE(da.fecha_inicio, (da.inicio AT TIME ZONE 'America/Lima')::date)
           ),
           LEAST(
             ($3::timestamptz AT TIME ZONE 'America/Lima')::date,
             COALESCE(da.fecha_fin, ($3::timestamptz AT TIME ZONE 'America/Lima')::date)
           ),
           '1 day'::interval
         ) AS dia(fecha)
         CROSS JOIN LATERAL (
           SELECT
             (dia.fecha::date + (da.inicio AT TIME ZONE 'America/Lima')::time)
               AT TIME ZONE 'America/Lima' AS inicio,
             (dia.fecha::date + (da.fin AT TIME ZONE 'America/Lima')::time)
               AT TIME ZONE 'America/Lima' AS fin
         ) AS ocurrencia
         CROSS JOIN LATERAL generate_series(
           GREATEST(ocurrencia.inicio, $2::timestamptz),
           LEAST(ocurrencia.fin, $3::timestamptz) - make_interval(mins => da.duracion_bloque_minutos),
           make_interval(mins => da.duracion_bloque_minutos)
         ) AS bloque(inicio)
         WHERE da.asesor_id = $1
           AND da.activo = true
           AND da.disponible = true
           AND da.recurrente = true
           AND da.usa_bloques = true
           AND EXTRACT(DOW FROM dia.fecha)::int = da.dia_semana
           AND ocurrencia.fin > $2::timestamptz
           AND ocurrencia.inicio < $3::timestamptz

         UNION ALL

         SELECT
           da.id AS disponibilidad_id,
           ocurrencia.inicio,
           ocurrencia.fin,
           CEIL(EXTRACT(EPOCH FROM (ocurrencia.fin - ocurrencia.inicio)) / 60)::int
             AS duracion_bloque_minutos
         FROM "AT".disponibilidad_asesor da
         CROSS JOIN LATERAL generate_series(
           GREATEST(
             ($2::timestamptz AT TIME ZONE 'America/Lima')::date,
             COALESCE(da.fecha_inicio, (da.inicio AT TIME ZONE 'America/Lima')::date)
           ),
           LEAST(
             ($3::timestamptz AT TIME ZONE 'America/Lima')::date,
             COALESCE(da.fecha_fin, ($3::timestamptz AT TIME ZONE 'America/Lima')::date)
           ),
           '1 day'::interval
         ) AS dia(fecha)
         CROSS JOIN LATERAL (
           SELECT
             (dia.fecha::date + (da.inicio AT TIME ZONE 'America/Lima')::time)
               AT TIME ZONE 'America/Lima' AS inicio,
             (dia.fecha::date + (da.fin AT TIME ZONE 'America/Lima')::time)
               AT TIME ZONE 'America/Lima' AS fin
         ) AS ocurrencia
         WHERE da.asesor_id = $1
           AND da.activo = true
           AND da.disponible = true
           AND da.recurrente = true
           AND da.usa_bloques = false
           AND EXTRACT(DOW FROM dia.fecha)::int = da.dia_semana
           AND ocurrencia.fin > $2::timestamptz
           AND ocurrencia.inicio < $3::timestamptz
       )
       SELECT
         b.disponibilidad_id,
         b.inicio,
         b.fin,
         b.inicio AS inicio_bloque,
         b.fin AS fin_bloque,
         b.duracion_bloque_minutos,
         'libre' AS estado
       FROM bloques b
       WHERE NOT EXISTS (
         SELECT 1
         FROM "AT".reuniones_asesor r
         WHERE r.asesor_id = $1
           AND r.estado <> 'cancelado'
           AND tstzrange(r.inicio, r.fin, '[)') &&
               tstzrange(b.inicio, b.fin, '[)')
       )
       AND NOT EXISTS (
         SELECT 1
         FROM "AT".validation_cita vc
         WHERE vc.advisor_id = $1
           AND vc.status IN (
             'pending',
             'payment_pending',
             'paid',
             'confirmed',
             'approved'
           )
           AND tstzrange(vc.start_at, vc.end_at, '[)') &&
               tstzrange(b.inicio, b.fin, '[)')
       )
       ORDER BY b.inicio ASC`,
      [asesorId, dto.desde, dto.hasta],
    );
    return { ok: true, data: result.rows };
  }

  private async crearOVolverRelacion(
    user: CurrentUser,
    asesorId: string,
    codigoPublicoId: string | null,
    dto: VincularAsesorDto,
  ) {
    if (asesorId === user.usuario_id) {
      throw new BadRequestException('No puedes vincularte contigo mismo');
    }

    const relacion = await this.databaseService.withTransaction(
      async (client) => {
        const asesor = await client.query(
          `SELECT id
           FROM "AT".usuarios
           WHERE id = $1 AND rol = 'asesor'
           LIMIT 1`,
          [asesorId],
        );

        if (!asesor.rows[0]) {
          throw new NotFoundException('Asesor no encontrado');
        }

        const existing = await client.query(
          `SELECT *
           FROM "AT".relaciones_asesor_estudiante
           WHERE asesor_id = $1
             AND estudiante_id = $2
           ORDER BY creado_en DESC
           LIMIT 1`,
          [asesorId, user.usuario_id],
        );

        if (existing.rows[0]) {
          return existing.rows[0];
        }

        const inserted = await client.query(
          `INSERT INTO "AT".relaciones_asesor_estudiante
             (asesor_id, estudiante_id, codigo_publico_id, estado)
           VALUES ($1, $2, $3, 'pendiente')
           RETURNING *`,
          [asesorId, user.usuario_id, codigoPublicoId],
        );

        await client.query(
          `INSERT INTO "AT".notifications
             (user_id, title, message, type, status, related_id)
           VALUES ($1, $2, $3, 'solicitud_asesor', 'unread', $4)
           ON CONFLICT DO NOTHING`,
          [
            asesorId,
            'Nueva solicitud de asesoría',
            dto.mensaje ||
              'Un estudiante solicitó vincularse contigo como asesor.',
            inserted.rows[0].id,
          ],
        );

        return inserted.rows[0];
      },
    );

    return {
      ok: true,
      message: 'Solicitud de vinculación enviada correctamente',
      mensaje: 'Solicitud de vinculación enviada correctamente',
      relacionId: relacion.id,
      asesorId: relacion.asesor_id,
      estudianteId: relacion.estudiante_id,
      codigoId: relacion.codigo_publico_id,
      estado: relacion.estado,
      data: relacion,
    };
  }

  private requireStudent(user: CurrentUser) {
    if (user.rol !== 'estudiante') {
      throw new ForbiddenException('Esta operación requiere rol estudiante');
    }
  }
}
