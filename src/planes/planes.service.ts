import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { createHash, randomUUID } from 'crypto';
import { PoolClient, QueryResultRow } from 'pg';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { CotizarTesisPlanDto } from './dto/cotizar-tesis-plan.dto';
import { IniciarPagoPlanDto } from './dto/iniciar-pago-plan.dto';

interface CotizacionRow extends QueryResultRow {
  plan_id: string;
  plan_nombre: string;
  tipo_tesis_id: string;
  tipo_tesis_codigo: string;
  tipo_tesis_nombre: string;
  precio_base: string;
  moneda: string;
}

export interface CotizacionPlan {
  plan_id: string;
  plan_nombre: string;
  tipo_tesis_id: string;
  tipo_tesis_codigo: string;
  tipo_tesis_nombre: string;
  nivel_academico: string;
  precio_base: number;
  porcentaje_nivel: number;
  monto_ajuste_nivel: number;
  descuento_analisis_estadistico: number;
  precio_total: number;
  moneda: string;
}

@Injectable()
export class PlanesService {
  constructor(private readonly databaseService: DatabaseService) {}

  async listar() {
    const result = await this.databaseService.query(
      `SELECT *
       FROM "AT".planes
       WHERE activo = true
       ORDER BY precio ASC, nombre ASC`,
    );
    return { ok: true, data: result.rows };
  }

  async disponibles() {
    const result = await this.databaseService.query(
      `SELECT
         p.*,
         COALESCE(pb_resumen.beneficios, '[]'::jsonb) AS beneficios
       FROM "AT".planes p
       LEFT JOIN (
         SELECT
           pb.plan_id,
           jsonb_agg(
             jsonb_build_object(
               'codigo', b.codigo,
               'nombre', b.nombre,
               'cantidad', pb.cantidad,
               'incluido', pb.incluido
             )
             ORDER BY b.nombre ASC
           ) AS beneficios
         FROM "AT".planes_beneficios pb
         JOIN "AT".beneficios_plan_catalogo b
           ON b.id = pb.beneficio_id
          AND b.activo = true
         WHERE pb.incluido = true
         GROUP BY pb.plan_id
       ) pb_resumen ON pb_resumen.plan_id = p.id
       WHERE p.activo = true
       ORDER BY p.precio ASC, p.nombre ASC`,
    );
    return { ok: true, data: result.rows };
  }

  async cotizar(dto: CotizarTesisPlanDto) {
    const cotizacion = await this.calcularCotizacion(this.databaseService, dto);
    return { ok: true, data: cotizacion };
  }

  async iniciarPago(user: CurrentUser, dto: IniciarPagoPlanDto) {
    const pago = await this.databaseService.withTransaction(async (client) => {
      const plan = await client.query<{
        id: string;
        nombre: string;
        precio: string;
      }>(
        `SELECT id, nombre, precio
         FROM "AT".planes
         WHERE id = $1 AND activo = true
         LIMIT 1`,
        [dto.planId],
      );

      if (!plan.rows[0]) {
        throw new NotFoundException('Plan no encontrado');
      }

      const codigoOperacion =
        dto.codigoOperacion ?? this.buildPaymentCode(randomUUID());

      const pagoResult = await client.query(
        `INSERT INTO "AT".pagos
           (pagador_id, concepto, monto, estado, codigo_operacion, tesis_id, metadata, nota_verificacion)
         VALUES ($1, $2, $3, 'pendiente', $4, $5, $6, $7)
         RETURNING *`,
        [
          user.usuario_id,
          `plan:${plan.rows[0].nombre}`,
          plan.rows[0].precio,
          codigoOperacion,
          dto.tesisId ?? null,
          { tipo: 'plan', plan_id: dto.planId },
          'Creado automaticamente',
        ],
      );

      await client.query(
        `INSERT INTO "AT".pagos_plan (pago_id, plan_id)
         VALUES ($1, $2)`,
        [pagoResult.rows[0].id, dto.planId],
      );

      return pagoResult.rows[0];
    });

    return {
      ok: true,
      message: 'Pago de plan iniciado correctamente',
      data: pago,
    };
  }

  async calcularCotizacion(
    executor: DatabaseService | PoolClient,
    dto: CotizarTesisPlanDto,
  ): Promise<CotizacionPlan> {
    const queryExecutor = executor as {
      query: (
        sql: string,
        params: unknown[],
      ) => Promise<{ rows: CotizacionRow[] }>;
    };

    if (!dto.planId) {
      throw new BadRequestException('El plan es obligatorio');
    }

    if (!dto.tipoTesisId) {
      throw new BadRequestException('El tipo de tesis es obligatorio');
    }

    const nivelAcademico = this.normalizeNivelAcademico(dto.nivelAcademico);
    const result = await queryExecutor.query(
      `SELECT
         p.id AS plan_id,
         p.nombre AS plan_nombre,
         tt.id AS tipo_tesis_id,
         tt.codigo AS tipo_tesis_codigo,
         tt.nombre AS tipo_tesis_nombre,
         ptp.precio_base,
         ptp.moneda
       FROM "AT".planes_tipos_tesis_precios ptp
       JOIN "AT".planes p ON p.id = ptp.plan_id
       JOIN "AT".tipos_tesis tt ON tt.id = ptp.tipo_tesis_id
       WHERE ptp.plan_id = $1
         AND ptp.tipo_tesis_id = $2
         AND ptp.activo = true
         AND p.activo = true
         AND tt.activo = true
       LIMIT 1`,
      [dto.planId, dto.tipoTesisId],
    );

    const row = result.rows[0];
    if (!row) {
      throw new BadRequestException(
        'No existe una configuración de precio para el plan y tipo de tesis enviados',
      );
    }

    const precioBase = Number(row.precio_base);
    const porcentajeNivel = this.getNivelPercentage(nivelAcademico);
    const montoAjusteNivel = Number(
      (precioBase * (porcentajeNivel / 100)).toFixed(2),
    );
    const descuentoAnalisis =
      dto.requiereAnalisisEstadistico === false
        ? 500
        : 0;
    const precioTotal = Number(
      Math.max(precioBase + montoAjusteNivel - descuentoAnalisis, 0).toFixed(2),
    );

    return {
      plan_id: row.plan_id,
      plan_nombre: row.plan_nombre,
      tipo_tesis_id: row.tipo_tesis_id,
      tipo_tesis_codigo: row.tipo_tesis_codigo,
      tipo_tesis_nombre: row.tipo_tesis_nombre,
      nivel_academico: nivelAcademico,
      precio_base: precioBase,
      porcentaje_nivel: porcentajeNivel,
      monto_ajuste_nivel: montoAjusteNivel,
      descuento_analisis_estadistico: descuentoAnalisis,
      precio_total: precioTotal,
      moneda: row.moneda || 'PEN',
    };
  }

  private normalizeNivelAcademico(nivelAcademico: string): string {
    if (!nivelAcademico || nivelAcademico.trim() === '') {
      throw new BadRequestException('El nivel académico es obligatorio');
    }

    const normalized = nivelAcademico.trim().toUpperCase();
    if (
      !['PREGRADO', 'MAESTRIA', 'ESPECIALIDAD', 'DOCTORADO'].includes(
        normalized,
      )
    ) {
      throw new BadRequestException(
        'Nivel académico inválido. Debe ser PREGRADO, MAESTRIA, ESPECIALIDAD o DOCTORADO',
      );
    }

    return normalized;
  }

  private getNivelPercentage(nivelAcademico: string): number {
    switch (nivelAcademico) {
      case 'MAESTRIA':
      case 'ESPECIALIDAD':
        return 15;
      case 'DOCTORADO':
        return 20;
      case 'PREGRADO':
      default:
        return 0;
    }
  }

  private buildPaymentCode(seed: string): string {
    return `PAY-${createHash('md5').update(seed).digest('hex').slice(0, 10)}`;
  }
}
