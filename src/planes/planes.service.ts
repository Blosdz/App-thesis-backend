import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PoolClient, QueryResultRow } from 'pg';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { CotizarTesisPlanDto } from './dto/cotizar-tesis-plan.dto';
import { IniciarPagoPlanDto } from './dto/iniciar-pago-plan.dto';

interface CotizacionRow extends QueryResultRow {
  plan_id: string;
  plan_nombre: string;
  tipo_tesis_id: string;
  tipo_tesis_nombre: string;
  precio_base: string;
  moneda: string;
  porcentaje_nivel: string | null;
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
         COALESCE(
           jsonb_agg(
             jsonb_build_object(
               'codigo', b.codigo,
               'nombre', b.nombre,
               'cantidad', pb.cantidad,
               'incluido', pb.incluido
             )
           ) FILTER (WHERE b.id IS NOT NULL),
           '[]'::jsonb
         ) AS beneficios
       FROM "AT".planes p
       LEFT JOIN "AT".planes_beneficios pb ON pb.plan_id = p.id AND pb.incluido = true
       LEFT JOIN "AT".beneficios_plan_catalogo b ON b.id = pb.beneficio_id AND b.activo = true
       WHERE p.activo = true
       GROUP BY p.id
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

      const pagoResult = await client.query(
        `INSERT INTO "AT".pagos
           (pagador_id, concepto, monto, estado, codigo_operacion, tesis_id, metadata)
         VALUES ($1, $2, $3, 'pendiente', $4, $5, $6)
         RETURNING *`,
        [
          user.usuario_id,
          `Pago plan ${plan.rows[0].nombre}`,
          plan.rows[0].precio,
          dto.codigoOperacion ?? null,
          dto.tesisId ?? null,
          { tipo: 'plan', plan_id: dto.planId },
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
  ): Promise<Record<string, unknown>> {
    const queryExecutor = executor as {
      query: (
        sql: string,
        params: unknown[],
      ) => Promise<{ rows: CotizacionRow[] }>;
    };
    const result = await queryExecutor.query(
      `SELECT
         p.id AS plan_id,
         p.nombre AS plan_nombre,
         tt.id AS tipo_tesis_id,
         tt.nombre AS tipo_tesis_nombre,
         ptp.precio_base,
         ptp.moneda,
         ana.valor AS porcentaje_nivel
       FROM "AT".planes_tipos_tesis_precios ptp
       JOIN "AT".planes p ON p.id = ptp.plan_id
       JOIN "AT".tipos_tesis tt ON tt.id = ptp.tipo_tesis_id
       LEFT JOIN "AT".ajustes_nivel_academico ana
         ON ana.nivel_academico = $3 AND ana.activo = true
       WHERE ptp.plan_id = $1
         AND ptp.tipo_tesis_id = $2
         AND ptp.activo = true
         AND p.activo = true
         AND tt.activo = true
       LIMIT 1`,
      [dto.planId, dto.tipoTesisId, dto.nivelAcademico],
    );

    const row = result.rows[0];
    if (!row) {
      throw new BadRequestException(
        'No existe precio activo para ese plan y tipo de tesis',
      );
    }

    const precioBase = Number(row.precio_base);
    const porcentajeNivel = Number(row.porcentaje_nivel ?? 0);
    const ajusteNivel = Number(
      (precioBase * (porcentajeNivel / 100)).toFixed(2),
    );
    const descuentoAnalisis =
      dto.requiereAnalisisEstadistico === false
        ? Number((precioBase * 0.1).toFixed(2))
        : 0;
    const totalFinal = Number(
      (precioBase + ajusteNivel - descuentoAnalisis).toFixed(2),
    );

    return {
      plan_id: row.plan_id,
      plan_nombre: row.plan_nombre,
      tipo_tesis_id: row.tipo_tesis_id,
      tipo_tesis_nombre: row.tipo_tesis_nombre,
      nivel_academico: dto.nivelAcademico,
      precio_base: precioBase,
      porcentaje_nivel: porcentajeNivel,
      ajuste_nivel: ajusteNivel,
      descuento_analisis_estadistico: descuentoAnalisis,
      total_final: totalFinal,
      moneda: row.moneda,
    };
  }
}
