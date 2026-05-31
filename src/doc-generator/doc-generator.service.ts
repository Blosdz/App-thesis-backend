import {
  BadGatewayException,
  HttpException,
  Injectable,
  StreamableFile,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Readable } from 'stream';
import type { ReadableStream as NodeReadableStream } from 'stream/web';

type JsonRequestInit = Omit<RequestInit, 'body'> & {
  body?: unknown;
};

type GenerateDocxOptions = {
  uploadToBackend?: boolean;
  authorization?: string;
};

@Injectable()
export class DocGeneratorService {
  private readonly baseUrl: string;
  private readonly backendBaseUrl: string;

  constructor(private readonly configService: ConfigService) {
    this.baseUrl = this.configService
      .get<string>('THESIS_DOC_GENERATOR_URL', 'http://127.0.0.1:8001')
      .replace(/\/+$/, '');
    const port = String(this.configService.get<string | number>('PORT', 3000));
    this.backendBaseUrl = this.configService
      .get<string>('THESIS_BACKEND_URL', `http://127.0.0.1:${port}`)
      .replace(/\/+$/, '');
  }

  getThesis(tesisId: string) {
    return this.request(`/theses/${tesisId}`);
  }

  listReferences(tesisId: string) {
    return this.request(`/theses/${tesisId}/references`);
  }

  createReference(tesisId: string, body: unknown) {
    return this.request(`/theses/${tesisId}/references`, {
      method: 'POST',
      body,
    });
  }

  updateReference(referenceId: string, body: unknown) {
    return this.request(`/references/${referenceId}`, {
      method: 'PATCH',
      body,
    });
  }

  deleteReference(referenceId: string) {
    return this.request(`/references/${referenceId}`, { method: 'DELETE' });
  }

  listIndex(tesisId: string) {
    return this.request(`/theses/${tesisId}/sections`);
  }

  createIndexSection(tesisId: string, body: unknown) {
    return this.request(`/theses/${tesisId}/sections`, {
      method: 'POST',
      body,
    });
  }

  replaceIndex(tesisId: string, body: unknown) {
    return this.request(`/theses/${tesisId}/sections`, {
      method: 'PUT',
      body,
    });
  }

  updateIndexSection(tesisId: string, sectionId: string, body: unknown) {
    return this.request(`/theses/${tesisId}/sections/${sectionId}`, {
      method: 'PATCH',
      body,
    });
  }

  deleteIndexSection(tesisId: string, sectionId: string) {
    return this.request(`/theses/${tesisId}/sections/${sectionId}`, {
      method: 'DELETE',
    });
  }

  generateDocx(tesisId: string, options: GenerateDocxOptions = {}) {
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
      body: options.uploadToBackend
        ? { upload_to_backend: true }
        : undefined,
    }).then((payload) =>
      this.withBackendDownloadUrl(payload, `/ai/tesis/documentos`),
    );
  }

  async downloadDocument(filename: string) {
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
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
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
}
