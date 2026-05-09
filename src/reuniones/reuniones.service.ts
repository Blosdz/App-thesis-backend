import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { GoogleService } from '../google/google.service';
import { ActualizarEstadoReunionDto } from './dto/actualizar-estado-reunion.dto';
import { CancelarReunionDto } from './dto/cancelar-reunion.dto';
import { CrearReunionDto } from './dto/crear-reunion.dto';
import { GuardarGoogleMeetDto } from './dto/guardar-google-meet.dto';
import { ResponderReservaDto } from './dto/responder-reserva.dto';

@Injectable()
export class ReunionesService {
  constructor(
    private readonly databaseService: DatabaseService,
    private readonly googleService: GoogleService,
  ) {}

  async crear(user: CurrentUser, dto: CrearReunionDto) {
    if (user.rol !== 'estudiante' && user.rol !== 'admin') {
      throw new ForbiddenException(
        'Esta operación requiere rol estudiante o admin',
      );
    }

    const reunion = await this.databaseService.withTransaction(
      async (client) => {
        let costo = dto.costoReunion ?? 0;
        let duracion = dto.duracionMinutos;
        let moneda = 'PEN';

        if (dto.tarifaId) {
          const tarifa = await client.query<{
            precio: string;
            duracion_minutos: number;
            moneda: string;
          }>(
            `SELECT precio, duracion_minutos, moneda
           FROM "AT".tarifas_asesor
           WHERE id = $1 AND asesor_id = $2 AND activo = true
           LIMIT 1`,
            [dto.tarifaId, dto.asesorId],
          );
          if (!tarifa.rows[0]) {
            throw new NotFoundException('Tarifa no encontrada');
          }
          costo = Number(tarifa.rows[0].precio);
          duracion = tarifa.rows[0].duracion_minutos;
          moneda = tarifa.rows[0].moneda ?? 'PEN';
        }

        const result = await client.query(
          `INSERT INTO "AT".reuniones_asesor
           (disponibilidad_id, asesor_id, estudiante_id, tesis_id, tarifa_id, estado,
            motivo, notas, modalidad, lugar, inicio, fin, duracion_minutos, costo_reunion,
            moneda, tipo_reunion)
         VALUES ($1, $2, $3, $4, $5, 'pendiente', $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
         RETURNING *`,
          [
            dto.disponibilidadId ?? null,
            dto.asesorId,
            user.usuario_id,
            dto.tesisId ?? null,
            dto.tarifaId ?? null,
            dto.motivo ?? null,
            dto.notas ?? null,
            dto.modalidad ?? 'virtual',
            dto.lugar ?? null,
            dto.inicio,
            dto.fin,
            duracion ?? this.diffMinutes(dto.inicio, dto.fin),
            costo,
            moneda,
            dto.tipoReunion ?? 'asesoria',
          ],
        );

        return result.rows[0];
      },
    );

    return { ok: true, message: 'Reunión creada correctamente', data: reunion };
  }

  async crearSolicitud(user: CurrentUser, dto: CrearReunionDto) {
    if (user.rol !== 'estudiante' && user.rol !== 'admin') {
      throw new ForbiddenException(
        'Esta operación requiere rol estudiante o admin',
      );
    }

    const duracion = dto.duracionMinutos ?? this.diffMinutes(dto.inicio, dto.fin);
    if (duracion <= 0) {
      throw new BadRequestException('La fecha fin debe ser mayor que la fecha inicio');
    }

    const result = await this.databaseService.withTransaction(async (client) => {
      const relacion = await client.query(
        `SELECT id
         FROM "AT".relaciones_asesor_estudiante
         WHERE asesor_id = $1
           AND estudiante_id = $2
           AND estado = 'activo'
         LIMIT 1`,
        [dto.asesorId, user.usuario_id],
      );

      if (!relacion.rows[0] && user.rol !== 'admin') {
        throw new ForbiddenException('No tienes una relación activa con este asesor');
      }

      const disponibilidad = await client.query<{
        id: string;
        asesor_id: string;
        inicio: string;
        fin: string;
        activo: boolean;
        disponible: boolean;
      }>(
        `SELECT id, asesor_id, inicio, fin, activo, disponible
         FROM "AT".disponibilidad_asesor
         WHERE id = $1 AND asesor_id = $2
         LIMIT 1`,
        [dto.disponibilidadId, dto.asesorId],
      );

      if (!disponibilidad.rows[0]) {
        throw new NotFoundException('No se encontró la disponibilidad del asesor');
      }

      if (!disponibilidad.rows[0].activo || !disponibilidad.rows[0].disponible) {
        throw new BadRequestException('La disponibilidad no está activa');
      }

      const overlaps = await client.query<{ exists: boolean }>(
        `SELECT EXISTS (
           SELECT 1
           FROM "AT".validation_cita vc
           WHERE vc.advisor_id = $1
             AND vc.status IN ('pending', 'payment_pending', 'paid', 'confirmed', 'approved')
             AND tstzrange(vc.start_at, vc.end_at, '[)') && tstzrange($2::timestamptz, $3::timestamptz, '[)')
         ) OR EXISTS (
           SELECT 1
           FROM "AT".reuniones_asesor r
           WHERE r.asesor_id = $1
             AND r.estado IN ('pendiente', 'confirmado')
             AND tstzrange(r.inicio, r.fin, '[)') && tstzrange($2::timestamptz, $3::timestamptz, '[)')
         ) AS exists`,
        [dto.asesorId, dto.inicio, dto.fin],
      );

      if (overlaps.rows[0]?.exists) {
        throw new BadRequestException('Ya existe una solicitud o cita en ese bloque');
      }

      const inserted = await client.query(
        `INSERT INTO "AT".validation_cita
           (user_id, advisor_id, tesis_id, disponibilidad_id, status,
            reservation_date, start_at, end_at, duration_minutes, motivo,
            modalidad, lugar, enlace_reunion, notas, tipo_servicio)
         VALUES ($1, $2, $3, $4, 'pending',
            ($5::timestamptz AT TIME ZONE 'America/Lima')::date,
            $5, $6, $7, $8, $9, $10, $11, $12, $13)
         RETURNING *`,
        [
          user.usuario_id,
          dto.asesorId,
          dto.tesisId ?? null,
          dto.disponibilidadId ?? null,
          dto.inicio,
          dto.fin,
          duracion,
          dto.motivo ?? null,
          dto.modalidad ?? 'virtual',
          dto.lugar ?? null,
          null,
          dto.notas ?? null,
          dto.tipoReunion ?? 'asesoria',
        ],
      );

      await client.query(
        `INSERT INTO "AT".notifications
           (user_id, title, message, type, status, related_id)
         VALUES ($1, 'Nueva solicitud de cita',
                 'Un estudiante quiere reservar una cita contigo',
                 'solicitud_cita', 'unread', $2)
         ON CONFLICT DO NOTHING`,
        [dto.asesorId, inserted.rows[0].id],
      );

      return inserted.rows[0];
    });

    return {
      ok: true,
      message: 'Solicitud de cita creada correctamente',
      data: result,
      validation_cita_id: result.id,
      estado: result.status,
    };
  }

  async misCitasEstudiante(user: CurrentUser) {
    const result = await this.databaseService.query(
      `SELECT r.*, ppa.nombre_mostrar AS asesor_nombre
       FROM "AT".reuniones_asesor r
       LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = r.asesor_id
       WHERE r.estudiante_id = $1
       ORDER BY r.inicio DESC`,
      [user.usuario_id],
    );
    return { ok: true, data: result.rows };
  }

  async misCitasAsesor(user: CurrentUser) {
    if (user.rol !== 'asesor') {
      throw new ForbiddenException('Esta operación requiere rol asesor');
    }
    const result = await this.databaseService.query(
      `SELECT r.*, pe.nombres, pe.apellidos
       FROM "AT".reuniones_asesor r
       LEFT JOIN "AT".perfil_estudiante pe ON pe.estudiante_id = r.estudiante_id
       WHERE r.asesor_id = $1
       ORDER BY r.inicio DESC`,
      [user.usuario_id],
    );
    return { ok: true, data: result.rows };
  }

  async historialValidacionesAsesor(user: CurrentUser, status?: string) {
    if (user.rol !== 'asesor') {
      throw new ForbiddenException('Esta operación requiere rol asesor');
    }

    const result = await this.databaseService.query(
      `SELECT
         vc.id AS validation_cita_id,
         vc.user_id AS estudiante_id,
         trim(coalesce(pe.nombres, '') || ' ' || coalesce(pe.apellidos, '')) AS estudiante_nombre,
         vc.tesis_id,
         t.titulo AS tesis_titulo,
         vc.disponibilidad_id,
         vc.status,
         vc.reservation_date,
         vc.start_at,
         vc.end_at,
         vc.duration_minutes,
         vc.motivo,
         vc.modalidad,
         vc.lugar,
         vc.enlace_reunion,
         vc.notas,
         vc.payment_id,
         vc.meeting_id,
         vc.created_at,
         vc.updated_at
       FROM "AT".validation_cita vc
       LEFT JOIN "AT".perfil_estudiante pe ON pe.estudiante_id = vc.user_id
       LEFT JOIN "AT".tesis t ON t.id = vc.tesis_id
       WHERE vc.advisor_id = $1
         AND ($2::text IS NULL OR vc.status = $2)
       ORDER BY vc.created_at DESC`,
      [user.usuario_id, status ?? null],
    );

    return { ok: true, data: result.rows };
  }

  async historialValidacionesEstudiante(user: CurrentUser, status?: string) {
    if (user.rol !== 'estudiante') {
      throw new ForbiddenException('Esta operación requiere rol estudiante');
    }

    const result = await this.databaseService.query(
      `SELECT
         vc.id AS validation_cita_id,
         vc.advisor_id,
         ppa.nombre_mostrar AS advisor_nombre,
         vc.tesis_id,
         t.titulo AS tesis_titulo,
         vc.disponibilidad_id,
         vc.status,
         vc.reservation_date,
         vc.start_at,
         vc.end_at,
         vc.duration_minutes,
         vc.motivo,
         vc.modalidad,
         vc.lugar,
         vc.enlace_reunion,
         vc.notas,
         vc.payment_id,
         vc.meeting_id,
         vc.created_at,
         vc.updated_at
       FROM "AT".validation_cita vc
       LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = vc.advisor_id
       LEFT JOIN "AT".tesis t ON t.id = vc.tesis_id
       WHERE vc.user_id = $1
         AND ($2::text IS NULL OR vc.status = $2)
       ORDER BY vc.created_at DESC`,
      [user.usuario_id, status ?? null],
    );

    return { ok: true, data: result.rows };
  }

  async detalle(user: CurrentUser, reunionId: string) {
    const result = await this.databaseService.query(
      `SELECT *
       FROM "AT".reuniones_asesor
       WHERE id = $1
         AND (estudiante_id = $2 OR asesor_id = $2 OR $3 = 'admin')
       LIMIT 1`,
      [reunionId, user.usuario_id, user.rol],
    );
    if (!result.rows[0]) {
      throw new NotFoundException('Reunión no encontrada');
    }
    return { ok: true, data: result.rows[0] };
  }

  async cancelar(
    user: CurrentUser,
    reunionId: string,
    dto: CancelarReunionDto,
  ) {
    const result = await this.databaseService.query(
      `UPDATE "AT".reuniones_asesor
       SET estado = 'cancelado',
           notas = COALESCE($3, notas),
           actualizado_en = now()
       WHERE id = $1
         AND (estudiante_id = $2 OR asesor_id = $2 OR $4 = 'admin')
       RETURNING *`,
      [reunionId, user.usuario_id, dto.motivo ?? null, user.rol],
    );
    if (!result.rows[0]) {
      throw new NotFoundException('Reunión no encontrada');
    }
    return {
      ok: true,
      message: 'Reunión cancelada correctamente',
      data: result.rows[0],
    };
  }

  async actualizarEstado(
    user: CurrentUser,
    reunionId: string,
    dto: ActualizarEstadoReunionDto,
  ) {
    const result = await this.databaseService.query(
      `UPDATE "AT".reuniones_asesor
       SET estado = $3,
           notas = COALESCE($4, notas),
           actualizado_en = now()
       WHERE id = $1
         AND (estudiante_id = $2 OR asesor_id = $2 OR $5 = 'admin')
       RETURNING *`,
      [
        reunionId,
        user.usuario_id,
        dto.estado,
        dto.comentario ?? null,
        user.rol,
      ],
    );

    if (!result.rows[0]) {
      throw new NotFoundException('Reunión no encontrada');
    }

    return { ok: true, message: 'Estado actualizado', data: result.rows[0] };
  }

  async responderReserva(
    user: CurrentUser,
    validationCitaId: string,
    dto: ResponderReservaDto,
  ) {
    if (user.rol !== 'asesor') {
      throw new ForbiddenException('Esta operación requiere rol asesor');
    }

    const result = await this.databaseService.withTransaction(async (client) => {
      const reservaResult = await client.query<any>(
        `SELECT *
         FROM "AT".validation_cita
         WHERE id = $1 AND advisor_id = $2
         FOR UPDATE`,
        [validationCitaId, user.usuario_id],
      );
      const reserva = reservaResult.rows[0];

      if (!reserva) {
        throw new NotFoundException('No se encontró la solicitud');
      }

      if (reserva.status !== 'pending') {
        throw new BadRequestException('La solicitud ya fue procesada');
      }

      if (dto.accion === 'rechazar') {
        await client.query(
          `UPDATE "AT".validation_cita
           SET status = 'rejected', validated_by = $2, validated_at = now()
           WHERE id = $1`,
          [validationCitaId, user.usuario_id],
        );

        return {
          ok: true,
          validation_cita_id: validationCitaId,
          pago_id: null,
          estado: 'rejected',
          accion: 'rechazada',
          mensaje: 'Solicitud rechazada',
        };
      }

      const overlap = await client.query<{ exists: boolean }>(
        `SELECT EXISTS (
           SELECT 1
           FROM "AT".validation_cita vc
           WHERE vc.advisor_id = $1
             AND vc.id <> $2
             AND vc.status IN ('payment_pending', 'paid', 'confirmed', 'approved')
             AND tstzrange(vc.start_at, vc.end_at, '[)') &&
                 tstzrange($3::timestamptz, $4::timestamptz, '[)')
         ) OR EXISTS (
           SELECT 1
           FROM "AT".reuniones_asesor r
           WHERE r.asesor_id = $1
             AND r.estado IN ('pendiente', 'confirmado')
             AND tstzrange(r.inicio, r.fin, '[)') &&
                 tstzrange($3::timestamptz, $4::timestamptz, '[)')
         ) AS exists`,
        [user.usuario_id, validationCitaId, reserva.start_at, reserva.end_at],
      );

      if (overlap.rows[0]?.exists) {
        throw new BadRequestException('El bloque ya fue tomado');
      }

      const esPresustentacion =
        String(reserva.tipo_servicio || reserva.motivo || '')
          .toLowerCase()
          .includes('presustent') ||
        String(reserva.motivo || '').toLowerCase().includes('pre-sustent');
      const suscripcion = await client.query<any>(
        `SELECT *
         FROM "AT".suscripciones_estudiante
         WHERE estudiante_id = $1
           AND estado = 'activo'
           AND (expira_en IS NULL OR expira_en > now())
         ORDER BY creado_en DESC
         LIMIT 1`,
        [reserva.user_id],
      );
      const sub = suscripcion.rows[0];
      const disponibles = sub
        ? esPresustentacion
          ? Number(sub.presustentaciones_incluidas || 0) -
            Number(sub.presustentaciones_usadas || 0)
          : Number(sub.asesorias_incluidas || 0) -
            Number(sub.asesorias_usadas || 0)
        : 0;

      if (sub && disponibles > 0) {
        await client.query(
          `UPDATE "AT".suscripciones_estudiante
           SET ${
             esPresustentacion
               ? 'presustentaciones_usadas = coalesce(presustentaciones_usadas, 0) + 1'
               : 'asesorias_usadas = coalesce(asesorias_usadas, 0) + 1'
           },
               actualizado_en = now()
           WHERE id = $1`,
          [sub.id],
        );

        const reunionId = await this.crearReunionDesdeReserva(
          client,
          reserva,
          null,
          true,
        );

        await client.query(
          `UPDATE "AT".validation_cita
           SET status = 'approved',
               payment_id = null,
               meeting_id = $2,
               validated_by = $3,
               validated_at = now()
           WHERE id = $1`,
          [validationCitaId, reunionId, user.usuario_id],
        );

        return {
          ok: true,
          validation_cita_id: validationCitaId,
          reunion_id: reunionId,
          pago_id: null,
          estado: 'approved',
          accion: 'aceptada_por_plan',
          mensaje: 'Solicitud aceptada con el plan del estudiante',
        };
      }

      const pago = await client.query<{ id: string }>(
        `INSERT INTO "AT".pagos
           (pagador_id, concepto, monto, estado, codigo_operacion, nota_verificacion)
         VALUES ($1, $2, $3, 'pendiente', $4, $5)
         RETURNING id`,
        [
          reserva.user_id,
          reserva.motivo || 'Reserva de asesoría',
          100,
          `PAY-${Math.random().toString(16).slice(2, 12).toUpperCase()}`,
          'Pago generado luego de validación del asesor',
        ],
      );

      await client.query(
        `UPDATE "AT".validation_cita
         SET status = 'payment_pending',
             payment_id = $2,
             validated_by = $3,
             validated_at = now()
         WHERE id = $1`,
        [validationCitaId, pago.rows[0].id, user.usuario_id],
      );

      return {
        ok: true,
        validation_cita_id: validationCitaId,
        pago_id: pago.rows[0].id,
        estado: 'payment_pending',
        accion: 'pendiente_pago',
        mensaje: 'Solicitud aceptada y pago generado',
      };
    });

    return result;
  }

  async aprobarPagoReserva(
    user: CurrentUser,
    validationCitaId: string,
    dto: GuardarGoogleMeetDto,
  ) {
    if (user.rol !== 'admin') {
      throw new ForbiddenException('Esta operación requiere rol admin');
    }

    const result = await this.databaseService.withTransaction(async (client) => {
      const reservaResult = await client.query<any>(
        `SELECT *
         FROM "AT".validation_cita
         WHERE id = $1
         FOR UPDATE`,
        [validationCitaId],
      );
      const reserva = reservaResult.rows[0];

      if (!reserva) {
        throw new NotFoundException('No se encontró la reserva');
      }

      if (reserva.status !== 'payment_pending') {
        throw new BadRequestException('La reserva no está pendiente de pago');
      }

      await client.query(
        `UPDATE "AT".pagos
         SET estado = 'validado',
             verificado_por = $2,
             verificado_en = now(),
             actualizado_en = now()
         WHERE id = $1`,
        [reserva.payment_id, user.usuario_id],
      );

      const reunionId = await this.crearReunionDesdeReserva(
        client,
        reserva,
        reserva.payment_id,
        false,
        dto.enlaceReunion ?? null,
      );

      await client.query(
        `UPDATE "AT".validation_cita
         SET status = 'confirmed',
             meeting_id = $2,
             enlace_reunion = COALESCE($3, enlace_reunion)
         WHERE id = $1`,
        [validationCitaId, reunionId, dto.enlaceReunion ?? null],
      );

      return {
        ok: true,
        validation_cita_id: validationCitaId,
        reunion_id: reunionId,
        pago_id: reserva.payment_id,
        estado: 'confirmed',
        mensaje: 'Pago aprobado y reunión creada',
      };
    });

    return result;
  }

  async guardarGoogleMeet(
    user: CurrentUser,
    reunionId: string,
    dto: GuardarGoogleMeetDto,
  ) {
    const result = await this.databaseService.query(
      `UPDATE "AT".reuniones_asesor
       SET google_event_id = $3,
           enlace_reunion = $4,
           meet_codigo = $5,
           meet_error = $6,
           meet_creado_en = CASE WHEN $4::text IS NULL THEN meet_creado_en ELSE now() END,
           actualizado_en = now()
       WHERE id = $1
         AND (asesor_id = $2 OR $7 = 'admin')
       RETURNING *`,
      [
        reunionId,
        user.usuario_id,
        dto.googleEventId ?? null,
        dto.enlaceReunion ?? null,
        dto.meetCodigo ?? null,
        dto.meetError ?? null,
        user.rol,
      ],
    );
    if (!result.rows[0]) {
      throw new NotFoundException('Reunión no encontrada');
    }
    return {
      ok: true,
      message: 'Google Meet guardado correctamente',
      data: result.rows[0],
    };
  }

  async crearGoogleMeet(user: CurrentUser, reunionId: string) {
    const detalle = await this.databaseService.query<any>(
      `SELECT
         r.*,
         ppa.nombre_mostrar AS advisor_name,
         ppa.email_publico AS advisor_public_email,
         aau.email AS advisor_email,
         trim(coalesce(pe.nombres, '') || ' ' || coalesce(pe.apellidos, '')) AS student_name,
         eau.email AS student_email,
         t.titulo AS thesis_title
       FROM "AT".reuniones_asesor r
       LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = r.asesor_id
       LEFT JOIN "AT".usuarios au ON au.id = r.asesor_id
       LEFT JOIN "AT".auth_usuarios aau ON aau.id = au.auth_usuario_id
       LEFT JOIN "AT".perfil_estudiante pe ON pe.estudiante_id = r.estudiante_id
       LEFT JOIN "AT".usuarios eu ON eu.id = r.estudiante_id
       LEFT JOIN "AT".auth_usuarios eau ON eau.id = eu.auth_usuario_id
       LEFT JOIN "AT".tesis t ON t.id = r.tesis_id
       WHERE r.id = $1
         AND (r.asesor_id = $2 OR r.estudiante_id = $2 OR $3 = 'admin')
       LIMIT 1`,
      [reunionId, user.usuario_id, user.rol],
    );

    const reunion = detalle.rows[0];
    if (!reunion) {
      throw new NotFoundException('Reunión no encontrada');
    }

    const meet = await this.googleService.createMeetEvent({
      summary: `Reunion Tesis ${reunion.student_name || 'Estudiante'} - ${
        reunion.advisor_name || 'Asesor'
      }`,
      description: [reunion.notas, `reunion_id: ${reunion.id}`]
        .filter(Boolean)
        .join('\n\n'),
      location: reunion.lugar,
      startAt: reunion.inicio,
      endAt: reunion.fin,
      calendarId: reunion.advisor_email || reunion.advisor_public_email,
      attendees: [
        {
          email: reunion.advisor_email || reunion.advisor_public_email,
          displayName: reunion.advisor_name,
        },
        { email: reunion.student_email, displayName: reunion.student_name },
      ].filter((item) => item.email),
    });

    if (!meet.meetUrl) {
      throw new BadRequestException(
        'Google Calendar creó el evento, pero no devolvió enlace Meet',
      );
    }

    return this.guardarGoogleMeet(user, reunionId, {
      googleEventId: String(meet.eventData.id || ''),
      enlaceReunion: meet.meetUrl,
      meetCodigo: meet.meetCode ?? undefined,
    });
  }

  private diffMinutes(inicio: string, fin: string): number {
    return Math.max(
      1,
      Math.round((Date.parse(fin) - Date.parse(inicio)) / 60000),
    );
  }

  private async crearReunionDesdeReserva(
    client: {
      query: (sql: string, params?: unknown[]) => Promise<{ rows: any[] }>;
    },
    reserva: any,
    pagoId: string | null,
    cubiertaPorPlan: boolean,
    enlaceReunion: string | null = null,
  ) {
    const result = await client.query(
      `INSERT INTO "AT".reuniones_asesor
         (disponibilidad_id, asesor_id, estudiante_id, tesis_id, tarifa_id,
          estado, pago_id, motivo, notas, modalidad, lugar, enlace_reunion,
          inicio, fin, duracion_minutos, costo_reunion, moneda,
          origen_servicio, suscripcion_id, consume_cupo_plan, cubierta_por_plan,
          tipo_reunion)
       VALUES ($1, $2, $3, $4, null,
          'confirmado', $5, $6, $7, $8, $9, $10,
          $11, $12, $13, $14, 'PEN',
          $15, null, $16, $16, $17)
       RETURNING id`,
      [
        reserva.disponibilidad_id,
        reserva.advisor_id,
        reserva.user_id,
        reserva.tesis_id ?? null,
        pagoId,
        reserva.motivo ?? null,
        reserva.notas ?? null,
        reserva.modalidad ?? 'virtual',
        reserva.lugar ?? null,
        enlaceReunion ?? reserva.enlace_reunion ?? null,
        reserva.start_at,
        reserva.end_at,
        reserva.duration_minutes,
        pagoId ? 100 : 0,
        cubiertaPorPlan ? 'plan' : 'pago',
        cubiertaPorPlan,
        reserva.tipo_servicio ?? 'asesoria',
      ],
    );

    return result.rows[0].id as string;
  }
}
