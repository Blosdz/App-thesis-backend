import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { GoogleService } from '../google/google.service';
import { RegistrarPagoDto } from './dto/registrar-pago.dto';
import { RegistrarVoucherDto } from './dto/registrar-voucher.dto';
import { VerificarPagoDto } from './dto/verificar-pago.dto';

@Injectable()
export class PagosService {
  constructor(
    private readonly databaseService: DatabaseService,
    private readonly googleService: GoogleService,
  ) {}

  async misPagos(user: CurrentUser) {
    const result = await this.databaseService.query(
      `SELECT
         p.*,
         p.id AS pago_id,
         p.estado AS estado_pago,
         pp.plan_id,
         pl.nombre AS plan_nombre,
         COALESCE(p.tesis_id, vc.tesis_id, r.tesis_id) AS tesis_id,
         t.titulo AS tesis_titulo,
         vc.id AS validation_cita_id,
         COALESCE(r.estado, vc.status) AS estado_reunion,
         COALESCE(r.inicio, vc.start_at) AS inicio_reunion,
         COALESCE(r.fin, vc.end_at) AS fin_reunion,
         COALESCE(r.motivo, vc.motivo, p.metadata ->> 'motivo') AS motivo,
         COALESCE(r.modalidad, vc.modalidad, p.metadata ->> 'modalidad') AS modalidad,
         COALESCE(r.lugar, vc.lugar, p.metadata ->> 'lugar') AS lugar,
         COALESCE(r.enlace_reunion, vc.enlace_reunion, p.metadata ->> 'enlace_reunion') AS enlace_reunion,
         COALESCE(r.tipo_reunion, vc.tipo_servicio, p.metadata ->> 'tipo_servicio') AS tipo_servicio,
         COALESCE(r.asesor_id, vc.advisor_id) AS asesor_id,
         ppa.nombre_mostrar AS asesor_nombre,
         ppa.email_publico AS asesor_email,
         p.metadata ->> 'origen_pago' AS origen_pago
       FROM "AT".pagos p
       LEFT JOIN "AT".pagos_plan pp ON pp.pago_id = p.id
       LEFT JOIN "AT".planes pl ON pl.id = pp.plan_id
       LEFT JOIN "AT".validation_cita vc ON vc.payment_id = p.id
       LEFT JOIN "AT".reuniones_asesor r ON r.pago_id = p.id
       LEFT JOIN "AT".tesis t ON t.id = COALESCE(p.tesis_id, vc.tesis_id, r.tesis_id)
       LEFT JOIN "AT".perfil_publico_asesor ppa
         ON ppa.asesor_id = COALESCE(r.asesor_id, vc.advisor_id)
       WHERE p.pagador_id = $1
       ORDER BY p.creado_en DESC`,
      [user.usuario_id],
    );
    return { ok: true, data: result.rows };
  }

  async registrar(user: CurrentUser, dto: RegistrarPagoDto) {
    const result = await this.databaseService.query(
      `INSERT INTO "AT".pagos
         (pagador_id, concepto, monto, estado, codigo_operacion, tesis_id)
       VALUES ($1, $2, $3, 'pendiente', $4, $5)
       RETURNING *`,
      [
        user.usuario_id,
        dto.concepto,
        dto.monto,
        dto.codigoOperacion ?? null,
        dto.tesisId ?? null,
      ],
    );
    return {
      ok: true,
      message: 'Pago registrado correctamente',
      data: result.rows[0],
    };
  }

  async registrarVoucher(
    user: CurrentUser,
    pagoId: string,
    dto: RegistrarVoucherDto,
  ) {
    await this.assertPagoOwner(user, pagoId);
    const metadataPatch = dto.paymentMethod
      ? { metodo_pago: dto.paymentMethod }
      : {};

    const result = await this.databaseService.query(
      `UPDATE "AT".pagos
       SET documento_drive_id = COALESCE($3, documento_drive_id),
           url_archivo_drive = COALESCE($4, url_archivo_drive),
           nombre_archivo_voucher = COALESCE($5, nombre_archivo_voucher),
           tipo_mime_voucher = COALESCE($6, tipo_mime_voucher),
           tamano_bytes_voucher = COALESCE($7, tamano_bytes_voucher),
           codigo_operacion = COALESCE($2, codigo_operacion),
           metadata = COALESCE(metadata, '{}'::jsonb) || $8::jsonb,
           subido_en = now(),
           estado = 'voucher_subido',
           actualizado_en = now()
       WHERE id = $1
       RETURNING *`,
      [
        pagoId,
        dto.codigoOperacion ?? null,
        dto.documentoDriveId ?? null,
        dto.urlArchivoDrive ?? null,
        dto.nombreArchivoVoucher ?? null,
        dto.tipoMimeVoucher ?? null,
        dto.tamanoBytesVoucher ?? null,
        JSON.stringify(metadataPatch),
      ],
    );

    return {
      ok: true,
      message: 'Voucher registrado correctamente',
      data: result.rows[0],
    };
  }

  async subirVoucher(
    user: CurrentUser,
    pagoId: string,
    file: Express.Multer.File | undefined,
    dto: Pick<RegistrarVoucherDto, 'paymentMethod' | 'codigoOperacion'>,
  ) {
    if (!file) {
      throw new BadRequestException('Se requiere file');
    }

    const pago = await this.assertPagoOwner(user, pagoId);
    const rootFolderId = this.googleService.getDriveRootFolderId('vouchers');

    if (!rootFolderId) {
      throw new BadRequestException(
        'Falta GOOGLE_DRIVE_VOUCHERS_FOLDER_ID o GOOGLE_DRIVE_FOLDER_ID',
      );
    }

    const folderName = await this.buildVoucherFolderName(pago);
    const extension = file.originalname.includes('.')
      ? file.originalname.split('.').pop()
      : 'bin';
    const fileName = `${this.googleService.normalizeName(
      pago.concepto || 'voucher_pago',
    )}_${String(pago.id).slice(0, 8)}_${new Date()
      .toISOString()
      .replace(/[:.]/g, '-')}.${extension}`;
    const driveUser = await this.googleService.getDriveUser();
    const folder = await this.googleService.getOrCreateDriveFolder({
      folderName,
      parentFolderId: rootFolderId,
    });
    const driveFile = await this.googleService.uploadFileToDrive({
      file,
      folderId: folder.id,
      fileName,
    });

    const updated = await this.registrarVoucher(user, pagoId, {
      paymentMethod: dto.paymentMethod,
      codigoOperacion: dto.codigoOperacion,
      documentoDriveId: driveFile.id,
      urlArchivoDrive: driveFile.webViewLink ?? driveFile.webContentLink,
      nombreArchivoVoucher: file.originalname,
      tipoMimeVoucher: file.mimetype || driveFile.mimeType,
      tamanoBytesVoucher: file.size,
    });

    return {
      ...updated,
      folder,
      drive: {
        id: driveFile.id,
        webViewLink: driveFile.webViewLink ?? null,
        webContentLink: driveFile.webContentLink ?? null,
      },
      drive_user: driveUser,
    };
  }

  async adminListar() {
    const result = await this.databaseService.query(
      `${this.adminPaymentsQuery()}
       ORDER BY p.creado_en DESC`,
    );
    return { ok: true, data: result.rows };
  }

  async adminPendientesRevision() {
    const result = await this.databaseService.query(
      `${this.adminPaymentsQuery(
        `WHERE p.estado IN ('pendiente', 'voucher_subido')`,
      )}
       ORDER BY p.creado_en ASC`,
    );
    return { ok: true, data: result.rows };
  }

  async adminObtener(pagoId: string) {
    this.assertValidUuid(pagoId);

    const result = await this.databaseService.query(
      `${this.adminPaymentsQuery(`WHERE p.id = $1`)}
       LIMIT 1`,
      [pagoId],
    );
    if (!result.rows[0]) {
      throw new NotFoundException('Pago no encontrado');
    }
    return { ok: true, data: result.rows[0] };
  }

  async verificar(
    user: CurrentUser,
    pagoId: string,
    dto: VerificarPagoDto,
    _activarPlan = false,
  ) {
    this.assertValidUuid(pagoId);

    const verificationResult = await this.databaseService.withTransaction(
      async (client) => {
      const currentPago = await client.query<{
        id: string;
        estado: string;
      }>(
        `SELECT id, estado
         FROM "AT".pagos
         WHERE id = $1
         LIMIT 1
         FOR UPDATE`,
        [pagoId],
      );

      if (!currentPago.rows[0]) {
        throw new NotFoundException('Pago no encontrado');
      }

      const pagoResult = await client.query(
        `UPDATE "AT".pagos
         SET estado = $2,
             verificado_por = $3,
             verificado_en = now(),
             nota_verificacion = $4,
             actualizado_en = now()
         WHERE id = $1
         RETURNING *`,
        [
          pagoId,
          dto.aprobado ? 'validado' : 'rechazado',
          user.usuario_id,
          dto.notaVerificacion ?? null,
        ],
      );

      let reunionId: string | null = null;

      const planResult = await client.query<{
        plan_id: string;
        pagador_id: string;
        duracion_dias: number;
        caracteristicas: Record<string, unknown> | string | null;
      }>(
        `SELECT pp.plan_id, p.pagador_id, pl.duracion_dias, pl.caracteristicas
         FROM "AT".pagos_plan pp
         JOIN "AT".pagos p ON p.id = pp.pago_id
         JOIN "AT".planes pl ON pl.id = pp.plan_id
         WHERE pp.pago_id = $1
         LIMIT 1`,
        [pagoId],
      );

      const plan = planResult.rows[0];

      if (dto.aprobado && plan && currentPago.rows[0].estado !== 'validado') {
          const asesoriasIncluidas = this.getPlanCounter(
            plan.caracteristicas,
            'asesorias_incluidas',
          );
          const presustentacionesIncluidas = this.getPlanCounter(
            plan.caracteristicas,
            'presustentaciones_incluidas',
          );

          await client.query(
            `UPDATE "AT".suscripciones_estudiante
             SET estado = 'cancelado',
                 actualizado_en = now()
             WHERE estudiante_id = $1
               AND estado = 'activo'
               AND plan_id <> $2`,
            [plan.pagador_id, plan.plan_id],
          );

          const existingSuscripcion = await client.query<{ id: string }>(
            `UPDATE "AT".suscripciones_estudiante
             SET estado = 'activo',
                 iniciado_en = now(),
                 expira_en = now() + make_interval(days => $3),
                 asesorias_incluidas = $4,
                 asesorias_usadas = 0,
                 presustentaciones_incluidas = $5,
                 presustentaciones_usadas = 0,
                 actualizado_en = now()
             WHERE estudiante_id = $1
               AND plan_id = $2
             RETURNING id`,
            [
              plan.pagador_id,
              plan.plan_id,
              plan.duracion_dias,
              asesoriasIncluidas,
              presustentacionesIncluidas,
            ],
          );

          const suscripcion =
            existingSuscripcion.rows[0] ??
            (
              await client.query<{ id: string }>(
                `INSERT INTO "AT".suscripciones_estudiante
                   (
                     estudiante_id,
                     plan_id,
                     estado,
                     expira_en,
                     asesorias_incluidas,
                     presustentaciones_incluidas
                   )
                 VALUES (
                   $1,
                   $2,
                   'activo',
                   now() + make_interval(days => $3),
                   $4,
                   $5
                 )
                 RETURNING id`,
                [
                  plan.pagador_id,
                  plan.plan_id,
                  plan.duracion_dias,
                  asesoriasIncluidas,
                  presustentacionesIncluidas,
                ],
              )
            ).rows[0];

          await client.query(
            `DELETE FROM "AT".suscripcion_beneficios_consumo
             WHERE suscripcion_id = $1`,
            [suscripcion.id],
          );

          await client.query(
            `INSERT INTO "AT".suscripcion_beneficios_consumo
               (suscripcion_id, beneficio_id, cantidad_total, cantidad_usada)
             SELECT $1, pb.beneficio_id, COALESCE(pb.cantidad, 0), 0
             FROM "AT".planes_beneficios pb
             JOIN "AT".beneficios_plan_catalogo b
               ON b.id = pb.beneficio_id
              AND b.activo = true
             WHERE pb.plan_id = $2
               AND pb.incluido = true
               AND b.tipo_control = 'contador'`,
            [suscripcion.id, plan.plan_id],
          );
      } else if (dto.aprobado && !plan) {
        reunionId = await this.confirmarReservaPagada(client, pagoId);
      }

      return {
        pago: pagoResult.rows[0],
        reunionId,
      };
    },
    );

    return {
      ok: true,
      message: 'Pago verificado correctamente',
      data: {
        ...verificationResult.pago,
        reunion_id: verificationResult.reunionId,
      },
      reunion_id: verificationResult.reunionId,
    };
  }

  private async confirmarReservaPagada(
    client: {
      query: (sql: string, params?: unknown[]) => Promise<{ rows: any[] }>;
    },
    pagoId: string,
  ) {
    const reservaResult = await client.query(
      `SELECT
         vc.*,
         p.monto
       FROM "AT".validation_cita vc
       JOIN "AT".pagos p ON p.id = vc.payment_id
       WHERE vc.payment_id = $1
       LIMIT 1
       FOR UPDATE OF vc`,
      [pagoId],
    );
    const reserva = reservaResult.rows[0];

    if (!reserva) {
      return null;
    }

    if (reserva.meeting_id) {
      await client.query(
        `UPDATE "AT".validation_cita
         SET status = 'confirmed',
             updated_at = now()
         WHERE id = $1`,
        [reserva.id],
      );

      return reserva.meeting_id as string;
    }

    const reunion = await client.query(
      `INSERT INTO "AT".reuniones_asesor
         (disponibilidad_id, asesor_id, estudiante_id, tesis_id, tarifa_id,
          estado, pago_id, motivo, notas, modalidad, lugar, enlace_reunion,
          inicio, fin, duracion_minutos, costo_reunion, moneda,
          origen_servicio, suscripcion_id, consume_cupo_plan, cubierta_por_plan,
          tipo_reunion)
       VALUES ($1, $2, $3, $4, null,
          'confirmado', $5, $6, $7, $8, $9, $10,
          $11, $12, $13, $14, 'PEN',
          'pago', null, false, false, $15)
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
        reserva.enlace_reunion ?? null,
        reserva.start_at,
        reserva.end_at,
        reserva.duration_minutes,
        reserva.monto ?? 0,
        reserva.tipo_servicio ?? 'asesoria',
      ],
    );

    await client.query(
      `UPDATE "AT".validation_cita
       SET status = 'confirmed',
           meeting_id = $2,
           updated_at = now()
       WHERE id = $1`,
      [reserva.id, reunion.rows[0].id],
    );

    await client.query(
      `UPDATE "AT".disponibilidad_asesor
       SET disponible = false,
           actualizado_en = now()
       WHERE id = $1`,
      [reserva.disponibilidad_id],
    );

    return reunion.rows[0].id;
  }

  private adminPaymentsQuery(whereClause = '') {
    return `SELECT
         p.*,
         p.id AS pago_id,
         p.estado AS estado_pago,
         pp.plan_id,
         pl.nombre AS plan_nombre,
         pu.rol AS pagador_rol,
         pau.email AS pagador_email,
         CASE
           WHEN pu.rol = 'estudiante' THEN NULLIF(trim(coalesce(pe.nombres, '') || ' ' || coalesce(pe.apellidos, '')), '')
           WHEN pu.rol = 'asesor' THEN ppa_pagador.nombre_mostrar
           WHEN pu.rol = 'admin' THEN 'Administrador'
           ELSE NULL
         END AS pagador_nombre,
         pe.nombres AS estudiante_nombres,
         pe.apellidos AS estudiante_apellidos,
         pe.carrera AS estudiante_carrera,
         COALESCE(p.tesis_id, vc.tesis_id, rp.tesis_id, rvc.tesis_id) AS tesis_id,
         t.titulo AS tesis_titulo,
         vc.id AS validation_cita_id,
         COALESCE(rp.id, rvc.id, vc.meeting_id) AS reunion_id,
         COALESCE(rp.estado, rvc.estado, vc.status) AS estado_reunion,
         COALESCE(rp.inicio, rvc.inicio, vc.start_at) AS inicio_reunion,
         COALESCE(rp.inicio, rvc.inicio, vc.start_at) AS inicio,
         COALESCE(rp.fin, rvc.fin, vc.end_at) AS fin_reunion,
         COALESCE(rp.fin, rvc.fin, vc.end_at) AS fin,
         COALESCE(rp.motivo, rvc.motivo, vc.motivo, p.metadata ->> 'motivo') AS motivo,
         COALESCE(rp.modalidad, rvc.modalidad, vc.modalidad, p.metadata ->> 'modalidad') AS modalidad,
         COALESCE(rp.lugar, rvc.lugar, vc.lugar, p.metadata ->> 'lugar') AS lugar,
         COALESCE(rp.enlace_reunion, rvc.enlace_reunion, vc.enlace_reunion, p.metadata ->> 'enlace_reunion') AS enlace_reunion,
         COALESCE(rp.tipo_reunion, rvc.tipo_reunion, vc.tipo_servicio, p.metadata ->> 'tipo_servicio') AS tipo_servicio,
         COALESCE(rp.asesor_id, rvc.asesor_id, vc.advisor_id, pa.asesor_id) AS asesor_id,
         ppa.nombre_mostrar AS asesor_nombre,
         ppa.email_publico AS asesor_email,
         ppa.email_publico AS asesor_email_publico,
         v.id AS verificado_por_usuario_id,
         CASE
           WHEN vu.rol = 'estudiante' THEN NULLIF(trim(coalesce(vpe.nombres, '') || ' ' || coalesce(vpe.apellidos, '')), '')
           WHEN vu.rol = 'asesor' THEN vppa.nombre_mostrar
           WHEN vu.rol = 'admin' THEN 'Administrador'
           ELSE NULL
         END AS verificado_por_nombre,
         p.metadata ->> 'origen_pago' AS origen_pago
       FROM "AT".pagos p
       LEFT JOIN "AT".pagos_plan pp ON pp.pago_id = p.id
       LEFT JOIN "AT".planes pl ON pl.id = pp.plan_id
       LEFT JOIN "AT".pagos_asesor pa ON pa.pago_id = p.id
       LEFT JOIN "AT".validation_cita vc ON vc.payment_id = p.id
       LEFT JOIN "AT".reuniones_asesor rp ON rp.pago_id = p.id
       LEFT JOIN "AT".reuniones_asesor rvc ON rvc.id = vc.meeting_id
       LEFT JOIN "AT".tesis t ON t.id = COALESCE(p.tesis_id, vc.tesis_id, rp.tesis_id, rvc.tesis_id)
       LEFT JOIN "AT".usuarios pu ON pu.id = p.pagador_id
       LEFT JOIN "AT".auth_usuarios pau ON pau.id = pu.auth_usuario_id
       LEFT JOIN "AT".perfil_estudiante pe ON pe.estudiante_id = pu.id
       LEFT JOIN "AT".perfil_publico_asesor ppa_pagador ON ppa_pagador.asesor_id = pu.id
       LEFT JOIN "AT".perfil_publico_asesor ppa
         ON ppa.asesor_id = COALESCE(rp.asesor_id, rvc.asesor_id, vc.advisor_id, pa.asesor_id)
       LEFT JOIN "AT".usuarios v ON v.id = p.verificado_por
       LEFT JOIN "AT".usuarios vu ON vu.id = v.id
       LEFT JOIN "AT".perfil_estudiante vpe ON vpe.estudiante_id = vu.id
       LEFT JOIN "AT".perfil_publico_asesor vppa ON vppa.asesor_id = vu.id
       ${whereClause}`;
  }

  private getPlanCounter(
    caracteristicas: Record<string, unknown> | string | null,
    key: string,
  ) {
    const parsed =
      typeof caracteristicas === 'string'
        ? this.parsePlanCharacteristics(caracteristicas)
        : caracteristicas;
    const value = Number(parsed?.[key] ?? 0);

    if (!Number.isFinite(value) || value < 0) {
      return 0;
    }

    return Math.trunc(value);
  }

  private parsePlanCharacteristics(value: string) {
    try {
      return JSON.parse(value) as Record<string, unknown>;
    } catch {
      return {};
    }
  }

  private async assertPagoOwner(user: CurrentUser, pagoId: string) {
    this.assertValidUuid(pagoId);

    const result = await this.databaseService.query<{
      id: string;
      pagador_id: string;
      tesis_id: string | null;
      concepto: string | null;
      codigo_operacion: string | null;
      metadata: Record<string, unknown> | null;
    }>(
      `SELECT id, pagador_id, tesis_id, concepto, codigo_operacion, metadata
       FROM "AT".pagos
       WHERE id = $1
       LIMIT 1`,
      [pagoId],
    );

    const pago = result.rows[0];
    if (!pago) {
      throw new NotFoundException('Pago no encontrado');
    }

    if (pago.pagador_id !== user.usuario_id && user.rol !== 'admin') {
      throw new ForbiddenException(
        'No tienes permiso para modificar este pago',
      );
    }

    return pago;
  }

  private assertValidUuid(value: string) {
    const isUuid =
      typeof value === 'string' &&
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
        value,
      );

    if (!isUuid) {
      throw new BadRequestException('ID de pago inválido');
    }
  }

  private async buildVoucherFolderName(pago: {
    pagador_id: string;
    tesis_id: string | null;
  }) {
    const perfilResult = await this.databaseService.query<{
      nombres: string | null;
      apellidos: string | null;
    }>(
      `SELECT nombres, apellidos
       FROM "AT".perfil_estudiante
       WHERE estudiante_id = $1
       LIMIT 1`,
      [pago.pagador_id],
    );

    const studentName = this.googleService.normalizeName(
      perfilResult.rows[0]?.nombres || perfilResult.rows[0]?.apellidos
        ? `${perfilResult.rows[0]?.nombres || ''}_${perfilResult.rows[0]?.apellidos || ''}`
        : `usuario_${String(pago.pagador_id).slice(0, 8)}`,
      `usuario_${String(pago.pagador_id).slice(0, 8)}`,
    );

    if (!pago.tesis_id) {
      return `${studentName}_thesis`.slice(0, 160);
    }

    const tesisResult = await this.databaseService.query<{
      titulo: string | null;
    }>(
      `SELECT titulo
       FROM "AT".tesis
       WHERE id = $1
       LIMIT 1`,
      [pago.tesis_id],
    );

    const thesisTitle = this.googleService.normalizeName(
      tesisResult.rows[0]?.titulo || 'thesis',
      'thesis',
    );

    return `${studentName}_${thesisTitle}`.slice(0, 160);
  }
}
