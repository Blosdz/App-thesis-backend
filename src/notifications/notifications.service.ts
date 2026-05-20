import { Injectable, NotFoundException } from '@nestjs/common';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';

type Queryable = {
  query: (sql: string, params?: unknown[]) => Promise<{ rows: any[] }>;
};

export type CreateNotificationInput = {
  userId: string;
  title: string;
  description: string;
  type?: string;
  relatedId?: string | null;
  path?: string | null;
};

@Injectable()
export class NotificationsService {
  constructor(private readonly databaseService: DatabaseService) {}

  async create(input: CreateNotificationInput, queryable: Queryable = this.databaseService) {
    if (!input.userId || !input.title || !input.description) return null;

    const result = await queryable.query(
      `INSERT INTO "AT".notifications
         (user_id, title, message, type, related_id, status, path)
       VALUES ($1, $2, $3, $4, $5, 'unread', $6)
       RETURNING
         id,
         title,
         message AS description,
         type,
         related_id,
         (status = 'read' OR read_at IS NOT NULL) AS read,
         path,
         user_id,
         created_at,
         read_at`,
      [
        input.userId,
        input.title,
        input.description,
        input.type ?? 'general',
        input.relatedId ?? null,
        input.path ?? null,
      ],
    );

    return result.rows[0] ?? null;
  }

  async listForUser(user: CurrentUser) {
    const result = await this.databaseService.query(
      `SELECT
         id,
         title,
         message AS description,
         type,
         related_id,
         (status = 'read' OR read_at IS NOT NULL) AS read,
         path,
         user_id,
         created_at,
         read_at
       FROM "AT".notifications
       WHERE user_id = $1
         AND COALESCE(type, 'general') = ANY($2::text[])
       ORDER BY created_at DESC
       LIMIT 50`,
      [
        user.usuario_id,
        [
          'solicitud_asesor',
          'solicitud_cita',
          'estudiante_aceptado',
          'pago_generado',
          'pago_pendiente',
          'pago_aceptado',
          'sugerencia_tesis',
          'sugerencia_resuelta_estudiante',
          'reunion_creada',
          'url_sesion_generada',
          'curso_pago_generado',
          'curso_pago_pendiente',
          'curso_activado',
          'curso_vendido',
        ],
      ],
    );

    const unreadCount = result.rows.filter((item) => !item.read).length;

    return { ok: true, unreadCount, data: result.rows };
  }

  async markRead(user: CurrentUser, notificationId: string) {
    const result = await this.databaseService.query(
      `UPDATE "AT".notifications
       SET status = 'read',
           read_at = COALESCE(read_at, now())
       WHERE id = $1
         AND user_id = $2
       RETURNING
         id,
         title,
         message AS description,
         type,
         related_id,
         (status = 'read' OR read_at IS NOT NULL) AS read,
         path,
         user_id,
         created_at,
         read_at`,
      [notificationId, user.usuario_id],
    );

    if (!result.rows[0]) {
      throw new NotFoundException('Notificación no encontrada');
    }

    return { ok: true, data: result.rows[0] };
  }

  async markAllRead(user: CurrentUser) {
    const result = await this.databaseService.query(
      `UPDATE "AT".notifications
       SET status = 'read',
           read_at = COALESCE(read_at, now())
       WHERE user_id = $1
         AND status <> 'read'
         AND read_at IS NULL
       RETURNING id`,
      [user.usuario_id],
    );

    return { ok: true, updated: result.rowCount ?? result.rows.length };
  }
}
