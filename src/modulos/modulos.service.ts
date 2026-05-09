import { Injectable, NotFoundException } from '@nestjs/common';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { ActualizarModuloDto } from './dto/actualizar-modulo.dto';
import { CrearModuloTesisDto } from './dto/crear-modulo-tesis.dto';

@Injectable()
export class ModulosService {
  constructor(private readonly databaseService: DatabaseService) {}

  async listarCatalogo() {
    const result = await this.databaseService.query(
      `SELECT *
       FROM "AT".modulos_lista
       WHERE estado = 'activo'
       ORDER BY prioridad ASC, titulo ASC`,
    );
    return { ok: true, data: result.rows };
  }

  async listarPorTesis(tesisId: string) {
    const result = await this.databaseService.query(
      `SELECT mt.*, ml.titulo, ml.detalle, ml.estructura
       FROM "AT".modulos_tesis mt
       JOIN "AT".modulos_lista ml ON ml.id = mt.modulo_lista_id
       WHERE mt.tesis_id = $1
       ORDER BY ml.prioridad ASC, mt.creado_en ASC`,
      [tesisId],
    );
    return { ok: true, data: result.rows };
  }

  async crearParaTesis(_user: CurrentUser, dto: CrearModuloTesisDto) {
    const result = await this.databaseService.query(
      `INSERT INTO "AT".modulos_tesis (tesis_id, modulo_lista_id)
       VALUES ($1, $2)
       RETURNING *`,
      [dto.tesisId, dto.moduloListaId],
    );
    return {
      ok: true,
      message: 'Módulo agregado correctamente',
      data: result.rows[0],
    };
  }

  async actualizar(
    _user: CurrentUser,
    moduloId: string,
    dto: ActualizarModuloDto,
  ) {
    const result = await this.databaseService.query(
      `UPDATE "AT".modulos_tesis
       SET estado = COALESCE($2, estado),
           progreso = COALESCE($3, progreso),
           observacion = COALESCE($4, observacion),
           actualizado_en = now()
       WHERE id = $1
       RETURNING *`,
      [
        moduloId,
        dto.estado ?? null,
        dto.progreso ?? null,
        dto.observacion ?? null,
      ],
    );
    if (!result.rows[0]) {
      throw new NotFoundException('Módulo no encontrado');
    }
    return {
      ok: true,
      message: 'Módulo actualizado correctamente',
      data: result.rows[0],
    };
  }
}
