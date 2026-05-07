import { BadRequestException, Injectable } from '@nestjs/common';
import { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { GoogleDriveService } from '../google/google-drive.service';
import { RegistrarPagoDto } from './dto/registrar-pago.dto';
import { RegistrarVoucherDto } from './dto/registrar-voucher.dto';
import { UploadVoucherDto } from './dto/upload-voucher.dto';
import { VerificarPagoDto } from './dto/verificar-pago.dto';

@Injectable()
export class PagosService {
  constructor(
    private readonly databaseService: DatabaseService,
    private readonly googleDriveService: GoogleDriveService,
  ) {}

  async listar(user: CurrentUser) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_pago_listar_por_usuario($1, $2)',
      [user.usuario_id, user.rol],
    );

    return { ok: true, data: result.rows };
  }

  async registrar(user: CurrentUser, dto: RegistrarPagoDto) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_pago_registrar($1, $2, $3, $4, $5)',
      [
        user.usuario_id,
        dto.concepto,
        dto.monto,
        dto.tesisId ?? null,
        dto.metadata ?? {},
      ],
    );

    return { ok: true, data: result.rows[0] };
  }

  async registrarVoucher(
    user: CurrentUser,
    pagoId: string,
    dto: RegistrarVoucherDto,
  ) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_pago_registrar_voucher($1, $2, $3, $4, $5, $6, $7, $8, $9)',
      [
        pagoId,
        user.usuario_id,
        dto.codigoOperacion ?? null,
        dto.documentoDriveId ?? null,
        dto.urlArchivoDrive ?? null,
        dto.nombreArchivoVoucher ?? null,
        dto.tipoMimeVoucher ?? null,
        dto.tamanoBytesVoucher ?? null,
        dto.metadata ?? {},
      ],
    );

    return { ok: true, data: result.rows[0] };
  }

  async uploadVoucher(
    user: CurrentUser,
    pagoId: string,
    file: Express.Multer.File | undefined,
    dto: UploadVoucherDto,
  ) {
    if (!file) {
      throw new BadRequestException('Archivo requerido');
    }

    const uploaded = await this.googleDriveService.uploadFile(
      file,
      dto.carpetaDriveId,
    );
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_pago_registrar_voucher($1, $2, $3, $4, $5, $6, $7, $8, $9)',
      [
        pagoId,
        user.usuario_id,
        dto.codigoOperacion ?? null,
        uploaded.id ?? null,
        uploaded.webViewLink ?? null,
        file.originalname,
        file.mimetype,
        file.size,
        {},
      ],
    );

    return { ok: true, data: { archivo: uploaded, pago: result.rows[0] } };
  }

  async verificar(pagoId: string, dto: VerificarPagoDto) {
    const result = await this.databaseService.query<{ ok: boolean }>(
      'SELECT * FROM "AT".fn_pago_verificar($1, $2, $3)',
      [pagoId, dto.aprobado, dto.notaVerificacion ?? null],
    );

    return { ok: result.rows[0]?.ok ?? false, data: result.rows[0] };
  }
}
