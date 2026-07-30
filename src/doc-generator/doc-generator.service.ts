import {
  BadGatewayException,
  HttpException,
  Injectable,
  NotFoundException,
  StreamableFile,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Readable } from 'stream';
import type { ReadableStream as NodeReadableStream } from 'stream/web';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';

type JsonRequestInit = Omit<RequestInit, 'body'> & {
  body?: unknown;
};

type GenerateDocxOptions = {
  uploadToBackend?: boolean;
  authorization?: string;
};

const DOCX_MIME =
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
const DOCM_MIME = 'application/vnd.ms-word.document.macroEnabled.12';

@Injectable()
export class DocGeneratorService {
  private readonly baseUrl: string;
  private readonly backendBaseUrl: string;

  constructor(
    private readonly configService: ConfigService,
    private readonly databaseService: DatabaseService,
  ) {
    this.baseUrl = (
      this.configService.get<string>('THESIS_DOC_GENERATOR_URL')?.trim() ||
      'http://127.0.0.1:8000'
    ).replace(/\/+$/, '');
    const port = String(this.configService.get<string | number>('PORT', 3000));
    this.backendBaseUrl = this.configService
      .get<string>('THESIS_BACKEND_URL', `http://127.0.0.1:${port}`)
      .replace(/\/+$/, '');
  }

  async getThesis(tesisId: string, user: CurrentUser) {
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/theses/${tesisId}`);
  }

  async listReferences(tesisId: string, user: CurrentUser) {
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/theses/${tesisId}/references`);
  }

  async createReference(tesisId: string, body: unknown, user: CurrentUser) {
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/theses/${tesisId}/references`, {
      method: 'POST',
      body,
    });
  }

  async updateReference(referenceId: string, body: unknown, user: CurrentUser) {
    const tesisId = await this.getReferenceThesisId(referenceId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/references/${referenceId}`, {
      method: 'PATCH',
      body,
    });
  }

  async deleteReference(referenceId: string, user: CurrentUser) {
    const tesisId = await this.getReferenceThesisId(referenceId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/references/${referenceId}`, { method: 'DELETE' });
  }

  async listIndex(tesisId: string, user: CurrentUser) {
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/theses/${tesisId}/sections`);
  }

  async createIndexSection(tesisId: string, body: unknown, user: CurrentUser) {
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/theses/${tesisId}/sections`, {
      method: 'POST',
      body,
    });
  }

  async replaceIndex(tesisId: string, body: unknown, user: CurrentUser) {
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/theses/${tesisId}/sections`, {
      method: 'PUT',
      body,
    });
  }

  async updateIndexSection(
    tesisId: string,
    sectionId: string,
    body: unknown,
    user: CurrentUser,
  ) {
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/theses/${tesisId}/sections/${sectionId}`, {
      method: 'PATCH',
      body,
    });
  }

  async appendIndexSectionText(
    tesisId: string,
    sectionId: string,
    body: unknown,
    user: CurrentUser,
  ) {
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/theses/${tesisId}/sections/${sectionId}/append-text`, {
      method: 'POST',
      body,
    });
  }

  async deleteIndexSection(tesisId: string, sectionId: string, user: CurrentUser) {
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/theses/${tesisId}/sections/${sectionId}`, {
      method: 'DELETE',
    });
  }

  async applyFormatSkeleton(
    tesisId: string,
    skeletonSections: Array<{
      title: string;
      level: number;
      order: number;
      required: boolean;
    }>,
    user: CurrentUser,
  ) {
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/theses/${tesisId}/sections/from-skeleton`, {
      method: 'POST',
      body: { sections: skeletonSections },
    });
  }

  async generateDocx(
    tesisId: string,
    options: GenerateDocxOptions = {},
    user?: CurrentUser,
  ) {
    if (user) {
      await this.ensureThesisAccess(tesisId, user);
    }

    const headers: Record<string, string> = {};

    if (options.authorization) {
      headers.Authorization = options.authorization;
    }

    if (options.uploadToBackend) {
      headers['X-Backend-Base-Url'] = this.backendBaseUrl;
    }

    return this.request(`/theses/${tesisId}/documents/docx`, {
      method: 'POST',
      headers,
      body: options.uploadToBackend ? { upload_to_backend: true } : undefined,
    }).then((payload) =>
      this.withBackendDownloadUrl(payload, `/ai/tesis/documentos`),
    );
  }

  async getMetadataHarness(documentId: string, user: CurrentUser) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/documents/${documentId}/metadata-harness`);
  }

  async getRawData(documentId: string, user: CurrentUser) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/documents/${documentId}/raw-data`);
  }

  async getRawDocument(documentId: string, user: CurrentUser) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/documents/${documentId}/raw-document`);
  }

  async updateRawData(documentId: string, body: unknown, user: CurrentUser) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/documents/${documentId}/raw-data`, {
      method: 'PATCH',
      body,
    });
  }

  async extractRawData(documentId: string, user: CurrentUser) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/documents/${documentId}/raw-data/extract`, {
      method: 'POST',
    });
  }

  async extractSectionReferences(
    documentId: string,
    body: unknown,
    user: CurrentUser,
  ) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(
      `/documents/${documentId}/references/extract-section`,
      {
        method: 'POST',
        body,
      },
    );
  }

  async extractOutline(documentId: string, user: CurrentUser) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/documents/${documentId}/outline/extract`, { method: 'POST' });
  }

  async processDocument(documentId: string, user: CurrentUser) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/documents/${documentId}/process`, { method: 'POST' });
  }

  async listSections(documentId: string, user: CurrentUser) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/documents/${documentId}/sections`);
  }

  async getSection(documentId: string, sectionId: string, user: CurrentUser) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/documents/${documentId}/sections/${sectionId}`);
  }

  async updateSection(
    documentId: string,
    sectionId: string,
    body: unknown,
    user: CurrentUser,
  ) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/documents/${documentId}/sections/${sectionId}`, {
      method: 'PATCH',
      body,
    });
  }

  async listDocumentReferences(documentId: string, user: CurrentUser) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/documents/${documentId}/references`);
  }

  async getDocumentReference(
    documentId: string,
    referenceId: string,
    user: CurrentUser,
  ) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/documents/${documentId}/references/${referenceId}`);
  }

  async updateDocumentReference(
    documentId: string,
    referenceId: string,
    body: unknown,
    user: CurrentUser,
  ) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/documents/${documentId}/references/${referenceId}`, {
      method: 'PATCH',
      body,
    });
  }

  async getPreview(documentId: string, user: CurrentUser) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/documents/${documentId}/preview`);
  }

  async insertCitation(documentId: string, body: unknown, user: CurrentUser) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/documents/${documentId}/citations`, {
      method: 'POST',
      body,
    });
  }

  async insertHeading(documentId: string, body: unknown, user: CurrentUser) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/documents/${documentId}/headings`, {
      method: 'POST',
      body,
    });
  }

  async insertSubtitle(documentId: string, body: unknown, user: CurrentUser) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);
    return this.request(`/documents/${documentId}/subtitles`, {
      method: 'POST',
      body,
    });
  }

  async downloadEditableDocument(documentId: string, user: CurrentUser) {
    const tesisId = await this.getDocumentThesisId(documentId);
    await this.ensureThesisAccess(tesisId, user);

    let response: Response;
    try {
      response = await fetch(
        `${this.baseUrl}/documents/${encodeURIComponent(documentId)}/download`,
      );
    } catch (error) {
      throw new BadGatewayException({
        message: 'No se pudo descargar el documento desde thesis-doc-generator',
        detail: error instanceof Error ? error.message : error,
      });
    }

    if (!response.ok || !response.body) {
      const payload = await this.parseResponse(response);
      throw new HttpException(payload, response.status);
    }

    const contentDisposition =
      response.headers.get('content-disposition') ||
      `attachment; filename="documento.docx"`;
    const stream = Readable.fromWeb(
      response.body as unknown as NodeReadableStream<Uint8Array>,
    );
    return new StreamableFile(stream, {
      type:
        response.headers.get('content-type') ||
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      disposition: contentDisposition,
    });
  }

  async downloadDocument(filename: string, user: CurrentUser) {
    await this.ensureDocumentFilenameAccess(filename, user);
    let response: Response;
    try {
      response = await fetch(
        `${this.baseUrl}/documents/${encodeURIComponent(filename)}`,
      );
    } catch (error) {
      throw new BadGatewayException({
        message: 'No se pudo descargar el documento desde thesis-doc-generator',
        detail: error instanceof Error ? error.message : error,
      });
    }

    if (!response.ok || !response.body) {
      const payload = await this.parseResponse(response);
      throw new HttpException(payload, response.status);
    }

    const stream = Readable.fromWeb(
      response.body as unknown as NodeReadableStream<Uint8Array>,
    );
    return new StreamableFile(stream, {
      type:
        response.headers.get('content-type') ||
        this.wordMimeType(filename),
      disposition: `attachment; filename="${filename}"`,
    });
  }

  private async request(path: string, init: JsonRequestInit = {}) {
    let response: Response;
    try {
      response = await fetch(`${this.baseUrl}${path}`, {
        method: init.method ?? 'GET',
        headers: {
          'Content-Type': 'application/json',
          ...(init.headers ?? {}),
        },
        body: init.body === undefined ? undefined : JSON.stringify(init.body),
      });
    } catch (error) {
      throw new BadGatewayException({
        message: 'No se pudo conectar con thesis-doc-generator',
        detail: error instanceof Error ? error.message : error,
      });
    }

    const payload = await this.parseResponse(response);
    if (!response.ok) {
      throw new HttpException(payload, response.status);
    }
    return payload;
  }

  private async parseResponse(response: Response) {
    const text = await response.text();
    if (!text) {
      return null;
    }

    try {
      return JSON.parse(text);
    } catch {
      return text;
    }
  }

  private withBackendDownloadUrl(payload: unknown, prefix: string) {
    if (!payload || typeof payload !== 'object' || !('filename' in payload)) {
      return payload;
    }

    const filename = String((payload as { filename: unknown }).filename);
    return {
      ...payload,
      backend_download_url: `${prefix}/${encodeURIComponent(filename)}`,
    };
  }

  private wordMimeType(filename: string) {
    return filename.toLowerCase().endsWith('.docm') ? DOCM_MIME : DOCX_MIME;
  }

  private async ensureThesisAccess(tesisId: string, user: CurrentUser) {
    const result = await this.databaseService.query(
      `SELECT 1
       FROM "AT".tesis t
       WHERE t.id = $1
         AND t.eliminado_en IS NULL
         AND (
           t.estudiante_id = $2
           OR EXISTS (
             SELECT 1 FROM "AT".asesores_tesis at
             WHERE at.tesis_id = t.id AND at.asesor_id = $2 AND at.activo = true
           )
           OR $3 = 'admin'
         )
       LIMIT 1`,
      [tesisId, user.usuario_id, user.rol],
    );

    if (!result.rows[0]) {
      throw new NotFoundException('Tesis no encontrada');
    }
  }

  private async getReferenceThesisId(referenceId: string) {
    const result = await this.databaseService.query<{ tesis_id: string }>(
      `SELECT tesis_id
       FROM "AT".tesis_references
       WHERE id = $1 AND deleted_at IS NULL
       LIMIT 1`,
      [referenceId],
    );

    const tesisId = result.rows[0]?.tesis_id;
    if (!tesisId) {
      throw new NotFoundException('Referencia no encontrada');
    }
    return tesisId;
  }

  private async getDocumentThesisId(documentId: string) {
    const result = await this.databaseService.query<{ tesis_id: string }>(
      `SELECT tesis_id
       FROM "AT".documentos_tesis
       WHERE id = $1
       LIMIT 1`,
      [documentId],
    );

    const tesisId = result.rows[0]?.tesis_id;
    if (!tesisId) {
      throw new NotFoundException('Documento no encontrado');
    }
    return tesisId;
  }

  private async ensureDocumentFilenameAccess(
    filename: string,
    user: CurrentUser,
  ) {
    const result = await this.databaseService.query<{ tesis_id: string }>(
      `SELECT d.tesis_id
       FROM "AT".documentos_tesis d
       WHERE d.nombre_archivo = $1
       ORDER BY d.creado_en DESC
       LIMIT 1`,
      [filename],
    );

    const tesisId = result.rows[0]?.tesis_id;
    if (!tesisId) {
      throw new NotFoundException('Documento no encontrado');
    }

    await this.ensureThesisAccess(tesisId, user);
  }
}
