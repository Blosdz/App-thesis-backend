import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { GoogleService } from '../google/google.service';
import { ActualizarRevisionDocumentoDto } from './dto/actualizar-revision-documento.dto';
import { RegistrarDocumentoDto } from './dto/registrar-documento.dto';

const TIPOS_DOCUMENTO_ESTUDIANTE = [
  'reglamento',
  'instrumento',
  'rubrica',
  'criterios',
  'formatoAPA',
  'Vancouver',
  'fuente',
] as const;

const TIPO_DOCUMENTO_ALIASES: Record<string, string> = {
  vancouver: 'Vancouver',
};

@Injectable()
export class DocumentosService {
  constructor(
    private readonly databaseService: DatabaseService,
    private readonly googleService: GoogleService,
  ) {}

  private normalizarTipoDocumentoEstudiante(tipoDocumento?: string) {
    const tipo = tipoDocumento?.trim();
    const normalizado = tipo ? TIPO_DOCUMENTO_ALIASES[tipo] || tipo : null;

    if (
      !normalizado ||
      !TIPOS_DOCUMENTO_ESTUDIANTE.includes(
        normalizado as (typeof TIPOS_DOCUMENTO_ESTUDIANTE)[number],
      )
    ) {
      throw new BadRequestException(
        `tipo_documento inválido. Valores permitidos: ${TIPOS_DOCUMENTO_ESTUDIANTE.join(
          ', ',
        )}`,
      );
    }

    return normalizado;
  }

  async registrar(user: CurrentUser, dto: RegistrarDocumentoDto) {
    const result = await this.databaseService.query(
      `INSERT INTO "AT".documentos_tesis
         (tesis_id, subido_por, nombre_archivo, url_archivo_drive, documento_drive_id,
          ruta_storage, tipo_mime, tamano_bytes, estado_revision)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'pendiente')
       RETURNING *`,
      [
        dto.tesisId,
        user.usuario_id,
        dto.nombreArchivo ?? null,
        dto.urlArchivoDrive ?? null,
        dto.documentoDriveId ?? null,
        dto.rutaStorage ?? null,
        dto.tipoMime ?? null,
        dto.tamanoBytes ?? null,
      ],
    );
    return {
      ok: true,
      message: 'Documento registrado correctamente',
      data: result.rows[0],
    };
  }

  async crearCarpetaDrive(user: CurrentUser, tesisId: string) {
    const tesis = await this.obtenerTesisAutorizada(user, tesisId);

    if (tesis.carpeta_drive_id) {
      return {
        ok: true,
        message: 'La tesis ya tiene carpeta de Drive',
        folder_id: tesis.carpeta_drive_id,
      };
    }

    const rootFolderId = this.googleService.getDriveRootFolderId('documents');
    if (!rootFolderId) {
      throw new BadRequestException('GOOGLE_DRIVE_FOLDER_ID no configurado');
    }

    const estudiante = await this.databaseService.query<{
      nombres: string | null;
      apellidos: string | null;
    }>(
      `SELECT nombres, apellidos
       FROM "AT".perfil_estudiante
       WHERE estudiante_id = $1
       LIMIT 1`,
      [tesis.estudiante_id],
    );
    const studentName = this.googleService.normalizeName(
      `${estudiante.rows[0]?.nombres || ''}_${estudiante.rows[0]?.apellidos || ''}`,
      `usuario_${String(tesis.estudiante_id).slice(0, 8)}`,
    );
    const thesisTitle = this.googleService.normalizeName(tesis.titulo, 'tesis');
    const folderName = `${studentName}_${thesisTitle}`.slice(0, 160);
    const folder = await this.googleService.getOrCreateDriveFolder({
      folderName,
      parentFolderId: rootFolderId,
    });

    await this.databaseService.query(
      `UPDATE "AT".tesis
       SET carpeta_drive_id = $2, actualizado_en = now()
       WHERE id = $1`,
      [tesisId, folder.id],
    );

    return {
      ok: true,
      message: 'Carpeta Drive creada correctamente',
      folder_id: folder.id,
      folder_name: folderName,
    };
  }

  async subirArchivo(
    user: CurrentUser,
    tesisId: string,
    file: Express.Multer.File | undefined,
    {
      modo,
      tipoDocumento,
    }: { modo: string; tipoDocumento?: string | undefined },
  ) {
    if (!file) {
      throw new BadRequestException('Se requiere file');
    }

    const esDocumentoTesis = modo === 'tesis';
    const tipoDocumentoNormalizado = esDocumentoTesis
      ? undefined
      : this.normalizarTipoDocumentoEstudiante(tipoDocumento);

    let tesis = await this.obtenerTesisAutorizada(user, tesisId);
    if (!tesis.carpeta_drive_id) {
      await this.crearCarpetaDrive(user, tesisId);
      tesis = await this.obtenerTesisAutorizada(user, tesisId);
    }

    if (!tesis.carpeta_drive_id) {
      throw new BadRequestException('No se pudo determinar carpeta Drive');
    }

    const nextVersion =
      esDocumentoTesis ? await this.obtenerSiguienteVersion(tesisId) : 1;
    const extension = file.originalname.includes('.')
      ? file.originalname.split('.').pop()
      : 'bin';
    const safeTitle = this.googleService.normalizeName(tesis.titulo, 'tesis');
    const suffix =
      esDocumentoTesis ? `_v${nextVersion}` : `_${tipoDocumentoNormalizado}`;
    const driveFileName = `${safeTitle}${suffix}.${extension}`;
    const driveUser = await this.googleService.getDriveUser();
    const driveFile = await this.googleService.uploadFileToDrive({
      file,
      folderId: tesis.carpeta_drive_id,
      fileName: driveFileName,
    });

    if (esDocumentoTesis) {
      const inserted = await this.databaseService.query(
        `INSERT INTO "AT".documentos_tesis
           (tesis_id, subido_por, nombre_archivo, url_archivo_drive,
            documento_drive_id, version, estado_revision, comentario_revision,
            tipo_mime, tamano_bytes)
         VALUES ($1, $2, $3, $4, $5, $6, 'pendiente', null, $7, $8)
         RETURNING *`,
        [
          tesisId,
          user.usuario_id,
          file.originalname,
          driveFile.webViewLink ?? null,
          driveFile.id,
          nextVersion,
          file.mimetype || driveFile.mimeType || null,
          file.size,
        ],
      );

      return this.uploadResponse(inserted.rows[0], driveFile, driveUser);
    }

    const inserted = await this.databaseService.query(
      `INSERT INTO "AT".estudiante_documentos
         (thesis_id, nombre, tipo, url_google_doc, activo, creado_por)
       VALUES ($1, $2, $3, $4, true, $5)
       RETURNING *`,
      [
        tesisId,
        file.originalname,
        tipoDocumentoNormalizado,
        driveFile.webViewLink ?? null,
        user.usuario_id,
      ],
    );

    return this.uploadResponse(inserted.rows[0], driveFile, driveUser);
  }

  async listarPorTesis(user: CurrentUser, tesisId: string) {
    const result = await this.databaseService.query(
      `SELECT
         d.*,
         d.nombre_archivo AS nombre,
         d.url_archivo_drive AS url_google_doc,
         d.creado_en AS created_at,
         'tesis' AS tipo_documento_categoria
       FROM "AT".documentos_tesis d
       JOIN "AT".tesis t ON t.id = d.tesis_id
       WHERE d.tesis_id = $1
         AND (
           t.estudiante_id = $2
           OR EXISTS (
             SELECT 1 FROM "AT".asesores_tesis at
             WHERE at.tesis_id = t.id AND at.asesor_id = $2 AND at.activo = true
           )
           OR $3 = 'admin'
         )
       ORDER BY d.creado_en DESC`,
      [tesisId, user.usuario_id, user.rol],
    );
    return { ok: true, data: result.rows };
  }

  async listarApoyo(user: CurrentUser, tesisId: string) {
    const result = await this.databaseService.query(
      `SELECT
         ed.*,
         ed.thesis_id AS tesis_id,
         ed.nombre AS nombre_archivo,
         ed.tipo AS tipo_documento,
         ed.url_google_doc AS url_archivo_drive,
         ed.creado_en AS created_at,
         'apoyo' AS tipo_documento_categoria
       FROM "AT".estudiante_documentos ed
       JOIN "AT".tesis t ON t.id = ed.thesis_id
       WHERE ed.thesis_id = $1
         AND ed.activo = true
         AND (
           t.estudiante_id = $2
           OR EXISTS (
             SELECT 1 FROM "AT".asesores_tesis at
             WHERE at.tesis_id = t.id AND at.asesor_id = $2 AND at.activo = true
           )
           OR $3 = 'admin'
         )
       ORDER BY ed.creado_en DESC`,
      [tesisId, user.usuario_id, user.rol],
    );
    return { ok: true, data: result.rows };
  }

  async actualizarRevision(
    user: CurrentUser,
    documentoId: string,
    dto: ActualizarRevisionDocumentoDto,
  ) {
    const result = await this.databaseService.query(
      `UPDATE "AT".documentos_tesis d
       SET estado_revision = $3,
           comentario_revision = $4,
           actualizado_en = now()
       FROM "AT".tesis t
       WHERE d.tesis_id = t.id
         AND d.id = $1
         AND (
           EXISTS (
             SELECT 1 FROM "AT".asesores_tesis at
             WHERE at.tesis_id = t.id AND at.asesor_id = $2 AND at.activo = true
           )
           OR $5 = 'admin'
         )
       RETURNING d.*`,
      [
        documentoId,
        user.usuario_id,
        dto.estadoRevision,
        dto.comentarioRevision ?? null,
        user.rol,
      ],
    );
    if (!result.rows[0]) {
      throw new NotFoundException('Documento no encontrado');
    }
    return {
      ok: true,
      message: 'Revisión actualizada correctamente',
      data: result.rows[0],
    };
  }

  private async obtenerTesisAutorizada(user: CurrentUser, tesisId: string) {
    const result = await this.databaseService.query<{
      id: string;
      estudiante_id: string;
      titulo: string;
      carpeta_drive_id: string | null;
    }>(
      `SELECT t.id, t.estudiante_id, t.titulo, t.carpeta_drive_id
       FROM "AT".tesis t
       WHERE t.id = $1
         AND t.eliminado_en IS NULL
         AND (
           t.estudiante_id = $2
           OR EXISTS (
             SELECT 1 FROM "AT".asesores_tesis at
             WHERE at.tesis_id = t.id
               AND at.asesor_id = $2
               AND at.activo = true
           )
           OR $3 = 'admin'
         )
       LIMIT 1`,
      [tesisId, user.usuario_id, user.rol],
    );

    if (!result.rows[0]) {
      throw new NotFoundException('Tesis no encontrada');
    }

    return result.rows[0];
  }

  private async obtenerSiguienteVersion(tesisId: string) {
    const result = await this.databaseService.query<{ version: number }>(
      `SELECT version
       FROM "AT".documentos_tesis
       WHERE tesis_id = $1
       ORDER BY version DESC
       LIMIT 1`,
      [tesisId],
    );

    return Number(result.rows[0]?.version || 0) + 1;
  }

  private uploadResponse(
    data: unknown,
    driveFile: { id: string; webViewLink?: string; webContentLink?: string },
    driveUser: unknown,
  ) {
    return {
      ok: true,
      message: 'Documento subido correctamente',
      data,
      drive: {
        id: driveFile.id,
        webViewLink: driveFile.webViewLink ?? null,
        webContentLink: driveFile.webContentLink ?? null,
      },
      drive_user: driveUser,
    };
  }
}
