import { ForbiddenException, Injectable } from '@nestjs/common';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { GuardarPerfilAsesorDto } from './dto/guardar-perfil-asesor.dto';
import { GuardarPerfilEstudianteDto } from './dto/guardar-perfil-estudiante.dto';

@Injectable()
export class UsuariosService {
  constructor(private readonly databaseService: DatabaseService) {}

  async obtenerPerfilEstudiante(user: CurrentUser) {
    this.requireRole(user, 'estudiante');
    const result = await this.databaseService.query(
      `SELECT pe.*, u.email
       FROM "AT".perfil_estudiante pe
       JOIN "AT".usuarios usr ON usr.id = pe.estudiante_id
       JOIN "AT".auth_usuarios u ON u.id = usr.auth_usuario_id
       WHERE pe.estudiante_id = $1
       ORDER BY pe.actualizado_en DESC
       LIMIT 1`,
      [user.usuario_id],
    );

    return { ok: true, data: result.rows[0] ?? null };
  }

  async guardarPerfilEstudiante(
    user: CurrentUser,
    dto: GuardarPerfilEstudianteDto,
  ) {
    this.requireRole(user, 'estudiante');

    const perfil = await this.databaseService.withTransaction(
      async (client) => {
        const existing = await client.query<{ id: string }>(
          `SELECT id FROM "AT".perfil_estudiante
         WHERE estudiante_id = $1
         ORDER BY actualizado_en DESC
         LIMIT 1`,
          [user.usuario_id],
        );

        if (existing.rows[0]) {
          const updated = await client.query(
            `UPDATE "AT".perfil_estudiante
           SET nombres = $2,
               apellidos = $3,
               universidad_id = $4,
               carrera = $5,
               actualizado_en = now()
           WHERE id = $1
           RETURNING *`,
            [
              existing.rows[0].id,
              dto.nombres,
              dto.apellidos,
              dto.universidadId ?? null,
              dto.carrera ?? null,
            ],
          );
          return updated.rows[0];
        }

        const inserted = await client.query(
          `INSERT INTO "AT".perfil_estudiante
           (estudiante_id, nombres, apellidos, universidad_id, carrera)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
          [
            user.usuario_id,
            dto.nombres,
            dto.apellidos,
            dto.universidadId ?? null,
            dto.carrera ?? null,
          ],
        );
        return inserted.rows[0];
      },
    );

    return {
      ok: true,
      message: 'Perfil de estudiante guardado correctamente',
      data: perfil,
    };
  }

  async obtenerPerfilAsesor(user: CurrentUser) {
    this.requireRole(user, 'asesor');
    const result = await this.databaseService.query(
      `SELECT ppa.*
       FROM "AT".perfil_publico_asesor ppa
       WHERE ppa.asesor_id = $1
       ORDER BY ppa.actualizado_en DESC
       LIMIT 1`,
      [user.usuario_id],
    );

    return { ok: true, data: result.rows[0] ?? null };
  }

  async guardarPerfilAsesor(user: CurrentUser, dto: GuardarPerfilAsesorDto) {
    this.requireRole(user, 'asesor');
    const slug = dto.slug ?? this.slugify(dto.nombreMostrar);

    const perfil = await this.databaseService.withTransaction(
      async (client) => {
        const existing = await client.query<{ id: string }>(
          `SELECT id FROM "AT".perfil_publico_asesor
         WHERE asesor_id = $1
         ORDER BY actualizado_en DESC
         LIMIT 1`,
          [user.usuario_id],
        );

        const params = [
          dto.nombreMostrar,
          dto.universidadId ?? null,
          slug,
          dto.emailPublico ?? null,
          dto.biografia ?? null,
          dto.fotoUrl ?? null,
          dto.especialidadId ?? null,
          dto.carrera ?? null,
          dto.nivelAcademico ?? null,
        ];

        if (existing.rows[0]) {
          const updated = await client.query(
            `UPDATE "AT".perfil_publico_asesor
           SET nombre_mostrar = $2,
               universidad_id = $3,
               slug = $4,
               email_publico = $5,
               biografia = $6,
               foto_url = $7,
               especialidad_id = $8,
               carrera = $9,
               nivel_academico = $10,
               actualizado_en = now()
           WHERE id = $1
           RETURNING *`,
            [existing.rows[0].id, ...params],
          );
          return updated.rows[0];
        }

        const inserted = await client.query(
          `INSERT INTO "AT".perfil_publico_asesor
           (asesor_id, nombre_mostrar, universidad_id, slug, email_publico, biografia, foto_url,
            especialidad_id, carrera, nivel_academico)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         RETURNING *`,
          [user.usuario_id, ...params],
        );
        return inserted.rows[0];
      },
    );

    return {
      ok: true,
      message: 'Perfil de asesor guardado correctamente',
      data: perfil,
    };
  }

  async obtenerMiRol(user: CurrentUser) {
    return { ok: true, data: { rol: user.rol, usuario_id: user.usuario_id } };
  }

  private requireRole(user: CurrentUser, role: CurrentUser['rol']) {
    if (user.rol !== role) {
      throw new ForbiddenException(`Esta operación requiere rol ${role}`);
    }
  }

  private slugify(value: string): string {
    return value
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 150);
  }
}
