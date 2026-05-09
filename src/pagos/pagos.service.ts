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
      `SELECT *
       FROM "AT".pagos
       WHERE pagador_id = $1
       ORDER BY creado_en DESC`,
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

    const perfil = await this.databaseService.query<{
      nombres: string | null;
      apellidos: string | null;
    }>(
      `SELECT nombres, apellidos
       FROM "AT".perfil_estudiante
       WHERE estudiante_id = $1
       LIMIT 1`,
      [pago.pagador_id],
    );

    const folderName = this.googleService.normalizeName(
      perfil.rows[0]?.nombres || perfil.rows[0]?.apellidos
        ? `${perfil.rows[0]?.nombres || ''}_${perfil.rows[0]?.apellidos || ''}`
        : `usuario_${String(pago.pagador_id).slice(0, 8)}`,
      'voucher',
    );
    const extension = file.originalname.includes('.')
      ? file.originalname.split('.').pop()
      : 'bin';
    const fileName = `${this.googleService.normalizeName(
      pago.concepto || 'voucher_pago',
    )}_${String(pago.id).slice(0, 8)}_${new Date()
      .toISOString()
      .replace(/[:.]/g, '-')}.${extension}`;
    const accessToken = await this.googleService.getAccessToken('drive');
    const driveUser = await this.googleService.getDriveUser(accessToken);
    const folder = await this.googleService.createDriveFolder({
      folderName,
      parentFolderId: rootFolderId,
      accessToken,
    });
    const driveFile = await this.googleService.uploadFileToDrive({
      file,
      folderId: folder.id,
      accessToken,
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
      `SELECT p.*, au.email AS pagador_email
       FROM "AT".pagos p
       LEFT JOIN "AT".usuarios u ON u.id = p.pagador_id
       LEFT JOIN "AT".auth_usuarios au ON au.id = u.auth_usuario_id
       ORDER BY p.creado_en DESC`,
    );
    return { ok: true, data: result.rows };
  }

  async adminPendientesRevision() {
    const result = await this.databaseService.query(
      `SELECT *
       FROM "AT".pagos
       WHERE estado IN ('pendiente', 'voucher_subido')
       ORDER BY creado_en ASC`,
    );
    return { ok: true, data: result.rows };
  }

  async adminObtener(pagoId: string) {
    const result = await this.databaseService.query(
      `SELECT p.*, pp.plan_id
       FROM "AT".pagos p
       LEFT JOIN "AT".pagos_plan pp ON pp.pago_id = p.id
       WHERE p.id = $1
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
    activarPlan = false,
  ) {
    const pago = await this.databaseService.withTransaction(async (client) => {
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

      if (!pagoResult.rows[0]) {
        throw new NotFoundException('Pago no encontrado');
      }

      if (dto.aprobado && activarPlan) {
        const planResult = await client.query<{
          plan_id: string;
          pagador_id: string;
          duracion_dias: number;
        }>(
          `SELECT pp.plan_id, p.pagador_id, pl.duracion_dias
           FROM "AT".pagos_plan pp
           JOIN "AT".pagos p ON p.id = pp.pago_id
           JOIN "AT".planes pl ON pl.id = pp.plan_id
           WHERE pp.pago_id = $1
           LIMIT 1`,
          [pagoId],
        );

        if (planResult.rows[0]) {
          await client.query(
            `INSERT INTO "AT".suscripciones_estudiante
               (estudiante_id, plan_id, estado, expira_en)
             VALUES ($1, $2, 'activo', now() + make_interval(days => $3))`,
            [
              planResult.rows[0].pagador_id,
              planResult.rows[0].plan_id,
              planResult.rows[0].duracion_dias,
            ],
          );
        }
      }

      return pagoResult.rows[0];
    });

    return { ok: true, message: 'Pago verificado correctamente', data: pago };
  }

  private async assertPagoOwner(user: CurrentUser, pagoId: string) {
    const result = await this.databaseService.query<{
      id: string;
      pagador_id: string;
      concepto: string | null;
      codigo_operacion: string | null;
      metadata: Record<string, unknown> | null;
    }>(
      `SELECT id, pagador_id, concepto, codigo_operacion, metadata
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
      throw new ForbiddenException('No tienes permiso para modificar este pago');
    }

    return pago;
  }
}
