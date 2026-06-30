import {
  BadGatewayException,
  HttpException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';

type JsonRequestInit = {
  method?: string;
  headers?: Record<string, string>;
  body?: unknown;
};

type ChartBase64 = {
  artifact_id: string;
  form_id: string;
  mime_type: string;
  data_base64: string;
};

@Injectable()
export class ColmenaService {
  private readonly baseUrl: string;

  constructor(
    private readonly configService: ConfigService,
    private readonly databaseService: DatabaseService,
  ) {
    this.baseUrl = (
      this.configService.get<string>('COLMENA_BACKEND_URL')?.trim() ||
      'http://127.0.0.1:8080'
    ).replace(/\/+$/, '');
  }

  // --- Formularios públicos (proxy sin auth) ---

  getPublicForm(code: string) {
    return this.request(`/api/public/forms/${encodeURIComponent(code)}`);
  }

  submitPublicResponse(code: string, body: unknown) {
    return this.request(
      `/api/public/forms/${encodeURIComponent(code)}/responses`,
      { method: 'POST', body },
    );
  }

  // --- Gráficos (proxy autenticado + persistencia) ---

  getChartBase64(formId: string, artifactId: string): Promise<ChartBase64> {
    return this.request(
      `/api/v1/forms/${encodeURIComponent(formId)}/chart-images/${encodeURIComponent(
        artifactId,
      )}/base64`,
    ) as Promise<ChartBase64>;
  }

  async importChartToThesis(
    tesisId: string,
    formId: string,
    artifactId: string,
    user: CurrentUser,
    title?: string,
  ) {
    await this.ensureThesisAccess(tesisId, user);
    const chart = await this.getChartBase64(formId, artifactId);

    const result = await this.databaseService.query<{ id: string }>(
      `INSERT INTO "AT".colmena_graficos_tesis
         (tesis_id, colmena_form_id, colmena_artifact_id, titulo, mime_type, data_base64)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING id`,
      [
        tesisId,
        chart.form_id || formId,
        chart.artifact_id || artifactId,
        title ?? null,
        chart.mime_type ?? null,
        chart.data_base64,
      ],
    );

    return {
      id: result.rows[0]?.id,
      tesis_id: tesisId,
      colmena_form_id: chart.form_id || formId,
      colmena_artifact_id: chart.artifact_id || artifactId,
      mime_type: chart.mime_type,
    };
  }

  async listThesisCharts(tesisId: string, user: CurrentUser) {
    await this.ensureThesisAccess(tesisId, user);
    const result = await this.databaseService.query(
      `SELECT id, colmena_form_id, colmena_artifact_id, titulo, mime_type, creado_en
       FROM "AT".colmena_graficos_tesis
       WHERE tesis_id = $1
       ORDER BY creado_en DESC`,
      [tesisId],
    );
    return result.rows;
  }

  // --- Helpers (espejo de DocGeneratorService) ---

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
        message: 'No se pudo conectar con COLMENA',
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
}
