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

type BaremoLevel = {
  label: string;
  min_value: number;
  max_value: number;
  severity_order: number;
  interpretation: string | null;
  source: string;
  n: number;
  percent: number;
};

type VariableBaremo = {
  scoring_config_id: string;
  scoring_config_name: string;
  variable_label: string;
  scoring_level: string;
  score_min: number | null;
  score_max: number | null;
  baremo_source: string;
  valid_n: number;
  mean_score: number | null;
  sd_score: number | null;
  mean_level: string | null;
  mean_interpretation: string | null;
  levels: BaremoLevel[];
  warnings: string[];
};

type BaremoResolution = {
  form_id: string;
  project_id: string;
  resolved_variables: number;
  items: VariableBaremo[];
  warnings: string[];
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

  // --- Baremos (proxy autenticado + persistencia) ---

  getBaremoResolution(
    formId: string,
    levelsCount = 3,
  ): Promise<BaremoResolution> {
    return this.request(
      `/api/v1/forms/${encodeURIComponent(
        formId,
      )}/scoring/baremos/resolution?levels_count=${levelsCount}`,
    ) as Promise<BaremoResolution>;
  }

  async listFormBaremos(tesisId: string, formId: string, user: CurrentUser) {
    await this.ensureThesisAccess(tesisId, user);
    return this.getBaremoResolution(formId);
  }

  async importBaremoToThesis(
    tesisId: string,
    formId: string,
    scoringConfigId: string,
    user: CurrentUser,
    title?: string,
  ) {
    await this.ensureThesisAccess(tesisId, user);
    const resolution = await this.getBaremoResolution(formId);
    const item = resolution.items.find(
      (i) => i.scoring_config_id === scoringConfigId,
    );
    if (!item) {
      throw new NotFoundException('Baremo no encontrado para este formulario');
    }

    const metadata = {
      score_min: item.score_min,
      score_max: item.score_max,
      baremo_source: item.baremo_source,
      valid_n: item.valid_n,
      mean_score: item.mean_score,
      sd_score: item.sd_score,
      mean_level: item.mean_level,
      mean_interpretation: item.mean_interpretation,
      warnings: item.warnings,
    };

    const result = await this.databaseService.query<{ id: string }>(
      `INSERT INTO "AT".colmena_baremos_tesis
         (tesis_id, colmena_form_id, colmena_scoring_config_id, titulo, config_name,
          variable_label, scoring_level, levels, metadata)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb, $9::jsonb)
       RETURNING id`,
      [
        tesisId,
        formId,
        item.scoring_config_id,
        title ?? null,
        item.scoring_config_name,
        item.variable_label,
        item.scoring_level,
        JSON.stringify(item.levels),
        JSON.stringify(metadata),
      ],
    );

    return {
      id: result.rows[0]?.id,
      tesis_id: tesisId,
      colmena_form_id: formId,
      colmena_scoring_config_id: item.scoring_config_id,
      config_name: item.scoring_config_name,
      variable_label: item.variable_label,
    };
  }

  async listThesisBaremos(tesisId: string, user: CurrentUser) {
    await this.ensureThesisAccess(tesisId, user);
    const result = await this.databaseService.query(
      `SELECT id, colmena_form_id, colmena_scoring_config_id, titulo, config_name,
              variable_label, scoring_level, levels, creado_en
       FROM "AT".colmena_baremos_tesis
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
