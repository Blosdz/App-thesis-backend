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
import { VincularAsesorDto } from './dto/vincular-asesor.dto';

@Injectable()
export class AsesoresService {
  constructor(private readonly databaseService: DatabaseService) {}

  async obtenerAsesores() {
    const result = await this.databaseService.query(
      `SELECT
         u.id AS asesor_id,
         ppa.nombre_mostrar,
         ppa.slug,
         ppa.email_publico,
         ppa.biografia,
         ppa.foto_url,
         ppa.carrera,
         ppa.nivel_academico,
         e.nombre AS especialidad_nombre,
         uni.nombre AS universidad_nombre
       FROM "AT".usuarios u
       LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = u.id
       LEFT JOIN "AT".especialidades e ON e.id = ppa.especialidad_id
       LEFT JOIN "AT".universidades uni ON uni.id = ppa.universidad_id
       WHERE u.rol = 'asesor'
       ORDER BY ppa.nombre_mostrar ASC NULLS LAST, u.creado_en DESC`,
    );
    return { ok: true, data: result.rows };
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
       FROM "AT".perfil_publico_asesor
       WHERE slug = $1
       LIMIT 1`,
      [slug],
    );

    if (!asesor.rows[0]) {
      throw new NotFoundException('Asesor no encontrado');
    }

    return this.crearOVolverRelacion(
      user,
      asesor.rows[0].asesor_id,
      null,
      dto,
    );
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
       FROM "AT".codigos_publicos_asesor
       WHERE codigo_publico = upper($1)
         AND activo = true
       ORDER BY creado_en DESC
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
        dto.duracionBloqueMinutos ?? 30,
        dto.recurrente ?? false,
        dto.diaSemana ?? null,
        dto.fechaInicio ?? null,
        dto.fechaFin ?? null,
      ],
    );

    return {
      ok: true,
      message: 'Espacio libre creado correctamente',
      data: result.rows[0],
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
      `SELECT
         da.id AS disponibilidad_id,
         bloque.inicio,
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
         AND da.fin > $2::timestamptz
         AND da.inicio < $3::timestamptz
         AND NOT EXISTS (
           SELECT 1
           FROM "AT".reuniones_asesor r
           WHERE r.asesor_id = da.asesor_id
             AND r.estado <> 'cancelado'
             AND tstzrange(r.inicio, r.fin, '[)') &&
                 tstzrange(bloque.inicio, bloque.inicio + make_interval(mins => da.duracion_bloque_minutos), '[)')
         )
       ORDER BY bloque.inicio ASC`,
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
             AND estado IN ('pendiente', 'activo')
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
      data: relacion,
    };
  }

  private requireStudent(user: CurrentUser) {
    if (user.rol !== 'estudiante') {
      throw new ForbiddenException('Esta operación requiere rol estudiante');
    }
  }
}
