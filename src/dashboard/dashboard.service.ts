import { ForbiddenException, Injectable } from '@nestjs/common';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';

@Injectable()
export class DashboardService {
  constructor(private readonly databaseService: DatabaseService) {}

  async estudiante(user: CurrentUser) {
    if (user.rol !== 'estudiante') {
      throw new ForbiddenException('Esta operación requiere rol estudiante');
    }

    const [
      perfil,
      tesis,
      pagos,
      reuniones,
      validaciones,
      asesores,
      suscripcion,
      documentos,
    ] = await Promise.all([
      this.perfilEstudiante(user.usuario_id),
      this.tesisEstudiante(user.usuario_id),
      this.pagosEstudiante(user.usuario_id),
      this.reunionesEstudiante(user.usuario_id),
      this.validacionesEstudiante(user.usuario_id),
      this.asesoresEstudiante(user.usuario_id),
      this.suscripcionActiva(user.usuario_id),
      this.documentosRecientes(user.usuario_id),
    ]);

    const citas = this.mergeCitas(reuniones.rows, validaciones.rows);
    const now = Date.now();
    const citasProximas = citas
      .filter((cita) => {
        const inicio = cita.inicio || cita.start_at || cita.inicio_reunion;
        const status = String(cita.estado || cita.status || '').toLowerCase();
        return (
          inicio &&
          !Number.isNaN(new Date(inicio).getTime()) &&
          new Date(inicio).getTime() >= now &&
          !['cancelado', 'cancelled', 'rejected'].includes(status)
        );
      })
      .sort((a, b) => {
        const inicioA = a.inicio || a.start_at || a.inicio_reunion;
        const inicioB = b.inicio || b.start_at || b.inicio_reunion;
        return new Date(inicioA).getTime() - new Date(inicioB).getTime();
      });
    const proxima = citasProximas[0] ?? null;
    const pagosPendientes = pagos.rows.filter((pago) =>
      ['pendiente', 'voucher_subido', 'rechazado'].includes(
        String(pago.estado_pago || pago.estado || '').toLowerCase(),
      ),
    );
    const tesisActiva =
      tesis.rows.find((row) =>
        ['en_progreso', 'revision', 'pendiente_pago', 'borrador'].includes(
          String(row.estado || '').toLowerCase(),
        ),
      ) ??
      tesis.rows[0] ??
      null;

    return {
      ok: true,
      data: {
        resumen: {
          total_tesis: tesis.rows.length,
          total_pagos: pagos.rows.length,
          total_citas: citas.length,
          total_asesores: asesores.rows.length,
          cantidad_citas_proximas: citasProximas.length,
          pagos_pendientes: pagosPendientes.length,
          documentos_recientes: Number(documentos.rows[0]?.total || 0),
          tesis_id: tesisActiva?.id ?? null,
          tesis_titulo: tesisActiva?.titulo ?? null,
          proxima_reunion_id:
            proxima?.reunion_id || proxima?.meeting_id || proxima?.id || null,
          proxima_reunion_inicio:
            proxima?.inicio ||
            proxima?.start_at ||
            proxima?.inicio_reunion ||
            null,
          proxima_reunion_fin:
            proxima?.fin || proxima?.end_at || proxima?.fin_reunion || null,
          proxima_reunion_estado:
            proxima?.estado ||
            proxima?.status ||
            proxima?.estado_reunion ||
            null,
          proxima_reunion_enlace:
            proxima?.enlace_reunion ||
            proxima?.meet_link ||
            proxima?.enlace ||
            null,
          proximo_asesor_id: proxima?.asesor_id || proxima?.advisor_id || null,
          proximo_asesor_nombre:
            proxima?.asesor_nombre ||
            proxima?.advisor_nombre ||
            proxima?.nombre_mostrar ||
            null,
        },
        perfil: perfil.rows[0] ?? null,
        tesis: tesis.rows,
        suscripcion: suscripcion.rows[0] ?? null,
        citas,
        pagos: pagos.rows,
        asesores: asesores.rows,
      },
    };
  }

  private perfilEstudiante(estudianteId: string) {
    return this.databaseService.query(
      `SELECT
         pe.*,
         u.nombre AS universidad
       FROM "AT".perfil_estudiante pe
       LEFT JOIN "AT".universidades u ON u.id = pe.universidad_id
       WHERE pe.estudiante_id = $1
       LIMIT 1`,
      [estudianteId],
    );
  }

  private tesisEstudiante(estudianteId: string) {
    return this.databaseService.query(
      `SELECT *
       FROM "AT".tesis
       WHERE estudiante_id = $1
         AND eliminado_en IS NULL
       ORDER BY actualizado_en DESC NULLS LAST, creado_en DESC`,
      [estudianteId],
    );
  }

  private pagosEstudiante(estudianteId: string) {
    return this.databaseService.query(
      `SELECT
         p.*,
         p.id AS pago_id,
         p.estado AS estado_pago,
         pp.plan_id,
         pl.nombre AS plan_nombre,
         vc.id AS validation_cita_id,
         vc.meeting_id AS reunion_id,
         COALESCE(r.enlace_reunion, vc.enlace_reunion) AS enlace_reunion,
         COALESCE(r.inicio, vc.start_at) AS inicio_reunion,
         COALESCE(r.fin, vc.end_at) AS fin_reunion,
         COALESCE(r.motivo, vc.motivo) AS motivo
       FROM "AT".pagos p
       LEFT JOIN "AT".pagos_plan pp ON pp.pago_id = p.id
       LEFT JOIN "AT".planes pl ON pl.id = pp.plan_id
       LEFT JOIN "AT".validation_cita vc ON vc.payment_id = p.id
       LEFT JOIN "AT".reuniones_asesor r ON r.pago_id = p.id
       WHERE p.pagador_id = $1
       ORDER BY p.creado_en DESC`,
      [estudianteId],
    );
  }

  private reunionesEstudiante(estudianteId: string) {
    return this.databaseService.query(
      `SELECT
         r.id AS reunion_id,
         r.id,
         r.asesor_id,
         ppa.nombre_mostrar AS asesor_nombre,
         r.tesis_id,
         t.titulo AS tesis_titulo,
         r.estado,
         r.inicio,
         r.fin,
         r.motivo,
         r.modalidad,
         r.lugar,
         r.enlace_reunion,
         r.tipo_reunion AS tipo_servicio,
         r.pago_id,
         r.creado_en,
         r.actualizado_en
       FROM "AT".reuniones_asesor r
       LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = r.asesor_id
       LEFT JOIN "AT".tesis t ON t.id = r.tesis_id
       WHERE r.estudiante_id = $1
       ORDER BY r.inicio DESC`,
      [estudianteId],
    );
  }

  private validacionesEstudiante(estudianteId: string) {
    return this.databaseService.query(
      `SELECT
         vc.id AS validation_cita_id,
         vc.meeting_id AS reunion_id,
         vc.advisor_id AS asesor_id,
         ppa.nombre_mostrar AS asesor_nombre,
         vc.tesis_id,
         t.titulo AS tesis_titulo,
         vc.status,
         vc.start_at,
         vc.end_at,
         vc.motivo,
         vc.modalidad,
         vc.lugar,
         vc.enlace_reunion,
         vc.tipo_servicio,
         vc.payment_id,
         vc.created_at,
         vc.updated_at
       FROM "AT".validation_cita vc
       LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = vc.advisor_id
       LEFT JOIN "AT".tesis t ON t.id = vc.tesis_id
       WHERE vc.user_id = $1
       ORDER BY vc.start_at DESC`,
      [estudianteId],
    );
  }

  private asesoresEstudiante(estudianteId: string) {
    return this.databaseService.query(
      `SELECT
         r.*,
         ppa.nombre_mostrar,
         ppa.slug,
         ppa.foto_url,
         ppa.biografia,
         ppa.carrera
       FROM "AT".relaciones_asesor_estudiante r
       LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = r.asesor_id
       WHERE r.estudiante_id = $1
       ORDER BY r.creado_en DESC`,
      [estudianteId],
    );
  }

  private suscripcionActiva(estudianteId: string) {
    return this.databaseService.query(
      `SELECT se.*, p.nombre AS plan_nombre, p.caracteristicas
       FROM "AT".suscripciones_estudiante se
       JOIN "AT".planes p ON p.id = se.plan_id
       WHERE se.estudiante_id = $1
         AND se.estado = 'activo'
         AND (se.expira_en IS NULL OR se.expira_en > now())
       ORDER BY se.iniciado_en DESC
       LIMIT 1`,
      [estudianteId],
    );
  }

  private documentosRecientes(estudianteId: string) {
    return this.databaseService.query(
      `SELECT (
         SELECT count(*)
         FROM "AT".documentos_tesis d
         JOIN "AT".tesis t ON t.id = d.tesis_id
         WHERE t.estudiante_id = $1
           AND d.creado_en >= now() - interval '30 days'
       ) + (
         SELECT count(*)
         FROM "AT".estudiante_documentos ed
         JOIN "AT".tesis t ON t.id = ed.thesis_id
         WHERE t.estudiante_id = $1
           AND ed.creado_en >= now() - interval '30 days'
       ) AS total`,
      [estudianteId],
    );
  }

  private mergeCitas(reuniones: Array<any>, validaciones: Array<any>) {
    const byKey = new Map<string, any>();

    [...reuniones, ...validaciones].forEach((cita) => {
      const key =
        cita.reunion_id ||
        cita.meeting_id ||
        cita.id ||
        cita.validation_cita_id ||
        `${cita.start_at || cita.inicio}-${cita.asesor_id || cita.advisor_id}`;

      if (!key) return;

      byKey.set(key, { ...(byKey.get(key) || {}), ...cita });
    });

    return Array.from(byKey.values());
  }
}
