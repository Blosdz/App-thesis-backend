import { Injectable } from '@nestjs/common';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { EmailService } from '../email/email.service';
import { VerificarPagoDto } from '../pagos/dto/verificar-pago.dto';

@Injectable()
export class AdminService {
  constructor(
    private readonly databaseService: DatabaseService,
    private readonly emailService: EmailService,
  ) {}

  async listarUsuarios() {
    const result = await this.databaseService.query(
      `SELECT
         u.id AS usuario_id,
         u.auth_usuario_id,
         au.email,
         u.rol,
         u.verificado,
         au.activo,
         au.email_verificado,
         au.ultimo_login_en,
         u.creado_en,
         u.actualizado_en,
         pe.nombres AS estudiante_nombres,
         pe.apellidos AS estudiante_apellidos,
         pe.carrera AS estudiante_carrera,
         pe.universidad_id AS estudiante_universidad_id,
         ue.nombre AS estudiante_universidad,
         ppa.nombre_mostrar AS asesor_nombre_mostrar,
         ppa.email_publico AS asesor_email_publico,
         ppa.carrera AS asesor_carrera,
         ppa.nivel_academico AS asesor_nivel_academico,
         ppa.slug AS asesor_slug,
         ppa.especialidad_id AS asesor_especialidad_id,
         ea.nombre AS asesor_especialidad,
         ppa.universidad_id AS asesor_universidad_id,
         ua.nombre AS asesor_universidad
       FROM "AT".usuarios u
       JOIN "AT".auth_usuarios au ON au.id = u.auth_usuario_id
       LEFT JOIN "AT".perfil_estudiante pe ON pe.estudiante_id = u.id
       LEFT JOIN "AT".universidades ue ON ue.id = pe.universidad_id
       LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = u.id
       LEFT JOIN "AT".especialidades ea ON ea.id = ppa.especialidad_id
       LEFT JOIN "AT".universidades ua ON ua.id = ppa.universidad_id
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
    const reunion = result.rows[0] ?? null;

    if (reunion?.estado === 'confirmado') {
      await this.sendMeetingConfirmedEmails(reunion.id);
    }

    return {
      ok: true,
      admin_id: user.usuario_id,
      data: reunion,
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

    if (dto.aprobado && result?.id) {
      await this.sendMeetingConfirmedEmails(result.id);
      if (result.pago_id) {
        await this.sendPaymentSuccessEmail(result.pago_id);
      }
    }

    return { ok: true, data: result };
  }

  private async sendMeetingConfirmedEmails(reunionId: string) {
    const result = await this.databaseService.query<{
      estudiante_email: string | null;
      asesor_email: string | null;
      inicio: Date | string | null;
      enlace_reunion: string | null;
      motivo: string | null;
    }>(
      `SELECT
         estudiante_auth.email AS estudiante_email,
         asesor_auth.email AS asesor_email,
         r.inicio,
         r.enlace_reunion,
         r.motivo
       FROM "AT".reuniones_asesor r
       JOIN "AT".usuarios estudiante ON estudiante.id = r.estudiante_id
       JOIN "AT".auth_usuarios estudiante_auth ON estudiante_auth.id = estudiante.auth_usuario_id
       JOIN "AT".usuarios asesor ON asesor.id = r.asesor_id
       JOIN "AT".auth_usuarios asesor_auth ON asesor_auth.id = asesor.auth_usuario_id
       WHERE r.id = $1
       LIMIT 1`,
      [reunionId],
    );

    const reunion = result.rows[0];
    const recipients = [reunion?.estudiante_email, reunion?.asesor_email].filter(
      (email): email is string => Boolean(email),
    );
    if (!recipients.length) return;

    await this.emailService.sendMeetingConfirmedEmail({
      to: recipients,
      title: reunion?.motivo ? `Reunión confirmada: ${reunion.motivo}` : undefined,
      startAt: reunion?.inicio,
      meetingUrl: reunion?.enlace_reunion,
    });
  }

  private async sendPaymentSuccessEmail(pagoId: string) {
    const result = await this.databaseService.query<{
      email: string | null;
      concepto: string | null;
      monto: string | null;
      moneda: string | null;
    }>(
      `SELECT
         au.email,
         p.concepto,
         p.monto::text,
         COALESCE(p.metadata ->> 'moneda', 'PEN') AS moneda
       FROM "AT".pagos p
       JOIN "AT".usuarios u ON u.id = p.pagador_id
       JOIN "AT".auth_usuarios au ON au.id = u.auth_usuario_id
       WHERE p.id = $1
       LIMIT 1`,
      [pagoId],
    );

    const pago = result.rows[0];
    if (!pago?.email) return;

    await this.emailService.sendPaymentSuccessEmail({
      to: pago.email,
      concepto: pago.concepto,
      monto: pago.monto && pago.moneda ? `${pago.moneda} ${pago.monto}` : pago.monto,
    });
  }
}
