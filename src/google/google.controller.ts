import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { Roles } from '../common/decorators/roles.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import { RolesGuard } from '../common/guards/roles.guard';
import { DatabaseService } from '../database/database.service';
import { GoogleService } from './google.service';

@Controller('google')
export class GoogleController {
  constructor(
    private readonly databaseService: DatabaseService,
    private readonly googleService: GoogleService,
  ) {}

  @Get('health')
  health() {
    return {
      ok: true,
      message:
        'Google integration placeholder. Implementar jobs/services sin triggers cuando se conecten credenciales.',
    };
  }

  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles('admin')
  @Post('meet/procesar-cola')
  async procesarColaMeet(
    @Body() dto: { batchSize?: number; maxIntentos?: number } = {},
  ) {
    const batchSize = Math.min(Math.max(Number(dto.batchSize) || 5, 1), 25);
    const maxIntentos = Math.min(
      Math.max(Number(dto.maxIntentos) || 3, 1),
      10,
    );
    const cola = await this.databaseService.query<any>(
      `SELECT
         c.id AS cola_id,
         c.intentos,
         r.*,
         ppa.nombre_mostrar AS advisor_name,
         ppa.email_publico AS advisor_public_email,
         aau.email AS advisor_email,
         trim(coalesce(pe.nombres, '') || ' ' || coalesce(pe.apellidos, '')) AS student_name,
         eau.email AS student_email,
         t.titulo AS thesis_title
       FROM "AT".cola_google_meet c
       JOIN "AT".reuniones_asesor r ON r.id = c.reunion_id
       LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = r.asesor_id
       LEFT JOIN "AT".usuarios au ON au.id = r.asesor_id
       LEFT JOIN "AT".auth_usuarios aau ON aau.id = au.auth_usuario_id
       LEFT JOIN "AT".perfil_estudiante pe ON pe.estudiante_id = r.estudiante_id
       LEFT JOIN "AT".usuarios eu ON eu.id = r.estudiante_id
       LEFT JOIN "AT".auth_usuarios eau ON eau.id = eu.auth_usuario_id
       LEFT JOIN "AT".tesis t ON t.id = r.tesis_id
       WHERE c.estado IN ('pendiente', 'pending', 'error', 'failed')
         AND c.intentos < $2
       ORDER BY c.creado_en ASC
       LIMIT $1`,
      [batchSize, maxIntentos],
    );

    const resultados: Array<Record<string, unknown>> = [];

    for (const item of cola.rows) {
      await this.databaseService.query(
        `UPDATE "AT".cola_google_meet
         SET estado = 'procesando',
             intentos = intentos + 1,
             actualizado_en = now()
         WHERE id = $1`,
        [item.cola_id],
      );

      try {
        const meet = await this.googleService.createMeetEvent({
          summary: `Reunion Tesis ${item.student_name || 'Estudiante'} - ${
            item.advisor_name || 'Asesor'
          }`,
          description: [item.notas, `reunion_id: ${item.id}`]
            .filter(Boolean)
            .join('\n\n'),
          location: item.lugar,
          startAt: item.inicio,
          endAt: item.fin,
          calendarId: item.advisor_email || item.advisor_public_email,
          attendees: [
            {
              email: item.advisor_email || item.advisor_public_email,
              displayName: item.advisor_name,
            },
            { email: item.student_email, displayName: item.student_name },
          ].filter((attendee) => attendee.email),
        });

        await this.databaseService.query(
          `UPDATE "AT".reuniones_asesor
           SET google_event_id = $2,
               enlace_reunion = $3,
               meet_codigo = $4,
               meet_error = NULL,
               meet_creado_en = now(),
               actualizado_en = now()
           WHERE id = $1`,
          [
            item.id,
            String(meet.eventData.id || ''),
            meet.meetUrl,
            meet.meetCode ?? null,
          ],
        );
        await this.databaseService.query(
          `UPDATE "AT".cola_google_meet
           SET estado = 'completado',
               error = NULL,
               actualizado_en = now()
           WHERE id = $1`,
          [item.cola_id],
        );
        resultados.push({
          colaId: item.cola_id,
          reunionId: item.id,
          estado: 'completado',
          enlaceReunion: meet.meetUrl,
        });
      } catch (error) {
        const message =
          error instanceof Error ? error.message : 'Error creando Google Meet';
        const siguienteIntento = Number(item.intentos || 0) + 1;
        const estado = siguienteIntento >= maxIntentos ? 'fallido' : 'error';

        await this.databaseService.query(
          `UPDATE "AT".cola_google_meet
           SET estado = $2,
               error = $3,
               actualizado_en = now()
           WHERE id = $1`,
          [item.cola_id, estado, message],
        );
        await this.databaseService.query(
          `UPDATE "AT".reuniones_asesor
           SET meet_error = $2,
               actualizado_en = now()
           WHERE id = $1`,
          [item.id, message],
        );
        resultados.push({
          colaId: item.cola_id,
          reunionId: item.id,
          estado,
          error: message,
        });
      }
    }

    return {
      ok: true,
      procesados: resultados.length,
      resultados,
    };
  }
}
