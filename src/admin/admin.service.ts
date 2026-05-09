import { Injectable } from '@nestjs/common';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { VerificarPagoDto } from '../pagos/dto/verificar-pago.dto';

@Injectable()
export class AdminService {
  constructor(private readonly databaseService: DatabaseService) {}

  async listarUsuarios() {
    const result = await this.databaseService.query(
      `SELECT
         u.id,
         u.auth_usuario_id,
         au.email,
         u.rol,
         u.verificado,
         au.activo,
         au.email_verificado,
         au.ultimo_login_en,
         u.creado_en,
         u.actualizado_en
       FROM "AT".usuarios u
       JOIN "AT".auth_usuarios au ON au.id = u.auth_usuario_id
       ORDER BY u.creado_en DESC`,
    );
    return { ok: true, data: result.rows };
  }

  async encolarInvitacion(dto: {
    email: string;
    name: string;
    rol?: string | undefined;
  }) {
    const email = String(dto.email || '').trim().toLowerCase();
    const name = String(dto.name || '').trim().replace(/\s+/g, ' ').slice(0, 160);
    const rol = dto.rol === 'asesor' ? 'asesor' : 'estudiante';

    if (!email || !name) {
      return { ok: false, error: 'email y name son obligatorios' };
    }

    const existing = await this.databaseService.query<{
      id: string;
    }>(
      `SELECT id
       FROM "AT".invitaciones_pendientes
       WHERE email = $1
         AND estado IN ('pendiente', 'link_generado')
       ORDER BY creado_en DESC
       LIMIT 1`,
      [email],
    );
    const payload = {
      email,
      user_metadata: { rol, nombre: name, name },
    };

    if (existing.rows[0]) {
      await this.databaseService.query(
        `UPDATE "AT".invitaciones_pendientes
         SET nombre = $2,
             payload = $3,
             estado = 'pendiente',
             ultimo_error = null,
             actualizado_en = now()
         WHERE id = $1`,
        [existing.rows[0].id, name, payload],
      );

      return {
        ok: true,
        queued: true,
        id: existing.rows[0].id,
        estado: 'pendiente',
      };
    }

    const inserted = await this.databaseService.query<{
      id: string;
      estado: string;
    }>(
      `INSERT INTO "AT".invitaciones_pendientes
         (email, nombre, payload, estado, intentos)
       VALUES ($1, $2, $3, 'pendiente', 0)
       RETURNING id, estado`,
      [email, name, payload],
    );

    return {
      ok: true,
      queued: true,
      id: inserted.rows[0].id,
      estado: inserted.rows[0].estado,
    };
  }

  async procesarInvitaciones(batchSize = 5) {
    const limit = Math.max(1, Math.min(Number(batchSize) || 5, 25));
    const pendientes = await this.databaseService.query<{
      id: string;
      email: string;
      payload: Record<string, unknown> | null;
      intentos: number;
    }>(
      `SELECT id, email, payload, intentos
       FROM "AT".invitaciones_pendientes
       WHERE estado = 'pendiente'
       ORDER BY creado_en ASC
       LIMIT $1`,
      [limit],
    );
    const loginUrl =
      process.env.APP_LOGIN_URL ||
      `${process.env.APP_URL || 'http://localhost:5173'}/login`;
    const resultados: Array<Record<string, unknown>> = [];

    for (const inv of pendientes.rows) {
      const actionLink = `${loginUrl}?invite=${inv.id}&email=${encodeURIComponent(
        inv.email,
      )}`;

      await this.databaseService.query(
        `UPDATE "AT".invitaciones_pendientes
         SET estado = 'link_generado',
             payload = COALESCE(payload, '{}'::jsonb) || $2::jsonb,
             enviado_en = now(),
             actualizado_en = now(),
             ultimo_error = null,
             intentos = $3
         WHERE id = $1`,
        [
          inv.id,
          JSON.stringify({ action_link: actionLink }),
          Number(inv.intentos || 0) + 1,
        ],
      );

      resultados.push({
        id: inv.id,
        email: inv.email,
        estado: 'link_generado',
        action_link: actionLink,
      });
    }

    return {
      ok: true,
      procesadas: resultados.length,
      resultados,
    };
  }

  async actualizarEstadoReunion(
    user: CurrentUser,
    reunionId: string,
    dto: { estado: string; nota?: string | undefined },
  ) {
    const result = await this.databaseService.query(
      `UPDATE "AT".reuniones_asesor
       SET estado = $2,
           notas = COALESCE($3, notas),
           actualizado_en = now()
       WHERE id = $1
       RETURNING *`,
      [reunionId, dto.estado, dto.nota ?? null],
    );

    return {
      ok: true,
      admin_id: user.usuario_id,
      data: result.rows[0] ?? null,
    };
  }

  async verificarPagoReunion(
    user: CurrentUser,
    reunionId: string,
    dto: VerificarPagoDto,
  ) {
    const result = await this.databaseService.withTransaction(async (client) => {
      const reunion = await client.query<{
        id: string;
        pago_id: string | null;
      }>(
        `SELECT id, pago_id
         FROM "AT".reuniones_asesor
         WHERE id = $1
         LIMIT 1
         FOR UPDATE`,
        [reunionId],
      );

      if (!reunion.rows[0]?.pago_id) {
        return null;
      }

      await client.query(
        `UPDATE "AT".pagos
         SET estado = $2,
             verificado_por = $3,
             verificado_en = now(),
             nota_verificacion = $4,
             actualizado_en = now()
         WHERE id = $1`,
        [
          reunion.rows[0].pago_id,
          dto.aprobado ? 'validado' : 'rechazado',
          user.usuario_id,
          dto.notaVerificacion ?? null,
        ],
      );

      const updated = await client.query(
        `UPDATE "AT".reuniones_asesor
         SET estado = $2, actualizado_en = now()
         WHERE id = $1
         RETURNING *`,
        [reunionId, dto.aprobado ? 'confirmado' : 'cancelado'],
      );

      return updated.rows[0];
    });

    return { ok: true, data: result };
  }
}
