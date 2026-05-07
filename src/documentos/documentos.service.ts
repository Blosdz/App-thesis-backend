import { BadRequestException, Injectable } from '@nestjs/common';
import { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { GoogleDriveService } from '../google/google-drive.service';
import { ActualizarRevisionDocumentoDto } from './dto/actualizar-revision-documento.dto';
import { RegistrarDocumentoDto } from './dto/registrar-documento.dto';
import { UploadDocumentoDto } from './dto/upload-documento.dto';

@Injectable()
export class DocumentosService {
  constructor(
    private readonly databaseService: DatabaseService,
    private readonly googleDriveService: GoogleDriveService,
  ) {}

  async listarPorTesis(user: CurrentUser, tesisId: string) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_documento_listar_por_tesis($1, $2)',
      [user.usuario_id, tesisId],
    );

    return { ok: true, data: result.rows };
  }

  async registrar(user: CurrentUser, dto: RegistrarDocumentoDto) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_documento_registrar($1, $2, $3, $4, $5, $6, $7, $8, $9)',
      [
        dto.tesisId,
        user.usuario_id,
        dto.nombreArchivo,
        dto.urlArchivoDrive,
        dto.carpetaDriveId ?? null,
        dto.documentoDriveId ?? null,
        dto.version ?? 1,
        dto.tipoMime ?? null,
        dto.tamanoBytes ?? null,
      ],
    );

    return { ok: true, data: result.rows[0] };
  }

  async upload(
    user: CurrentUser,
    file: Express.Multer.File | undefined,
    dto: UploadDocumentoDto,
  ) {
    if (!file) {
      throw new BadRequestException('Archivo requerido');
    }

    const uploaded = await this.googleDriveService.uploadFile(
      file,
      dto.carpetaDriveId,
    );
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_documento_registrar($1, $2, $3, $4, $5, $6, $7, $8, $9)',
      [
        dto.tesisId,
        user.usuario_id,
        dto.nombreArchivo ?? file.originalname,
        uploaded.webViewLink ?? '',
        dto.carpetaDriveId ?? null,
        uploaded.id ?? null,
        1,
        file.mimetype,
        file.size,
      ],
    );

    return { ok: true, data: { archivo: uploaded, documento: result.rows[0] } };
  }

  async actualizarRevision(
    user: CurrentUser,
    documentoId: string,
    dto: ActualizarRevisionDocumentoDto,
  ) {
    const result = await this.databaseService.query<{ ok: boolean }>(
      'SELECT * FROM "AT".fn_documento_actualizar_revision($1, $2, $3, $4)',
      [
        user.usuario_id,
        documentoId,
        dto.estadoRevision,
        dto.comentarioRevision ?? null,
      ],
    );

    return { ok: result.rows[0]?.ok ?? false, data: result.rows[0] };
  }
}
