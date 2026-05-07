import { Injectable, NotFoundException } from '@nestjs/common';
import { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { ActualizarEstadoTesisDto } from './dto/actualizar-estado-tesis.dto';
import { CrearTesisDto } from './dto/crear-tesis.dto';

@Injectable()
export class TesisService {
  constructor(private readonly databaseService: DatabaseService) {}

  async listar(user: CurrentUser) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_tesis_listar_por_usuario($1)',
      [user.usuario_id],
    );

    return { ok: true, data: result.rows };
  }

  async obtenerDetalle(user: CurrentUser, tesisId: string) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_tesis_obtener_detalle($1, $2)',
      [user.usuario_id, tesisId],
    );

    if (result.rows.length === 0) {
      throw new NotFoundException('Tesis no encontrada');
    }

    return { ok: true, data: result.rows[0] };
  }

  async crear(user: CurrentUser, dto: CrearTesisDto) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_tesis_crear($1, $2, $3, $4)',
      [user.usuario_id, dto.universidadId, dto.titulo, dto.descripcion ?? null],
    );

    return { ok: true, data: result.rows[0] };
  }

  async actualizarEstado(
    user: CurrentUser,
    tesisId: string,
    dto: ActualizarEstadoTesisDto,
  ) {
    const result = await this.databaseService.query<{ ok: boolean }>(
      'SELECT * FROM "AT".fn_tesis_actualizar_estado($1, $2, $3)',
      [user.usuario_id, tesisId, dto.estado],
    );

    return { ok: result.rows[0]?.ok ?? false, data: result.rows[0] };
  }
}
