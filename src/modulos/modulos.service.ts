import { Injectable } from '@nestjs/common';
import { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { ActualizarModuloDto } from './dto/actualizar-modulo.dto';
import { CrearModuloTesisDto } from './dto/crear-modulo-tesis.dto';

@Injectable()
export class ModulosService {
  constructor(private readonly databaseService: DatabaseService) {}

  async listarPorTesis(user: CurrentUser, tesisId: string) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_modulo_listar_por_tesis($1, $2)',
      [user.usuario_id, tesisId],
    );

    return { ok: true, data: result.rows };
  }

  async crearParaTesis(
    user: CurrentUser,
    tesisId: string,
    dto: CrearModuloTesisDto,
  ) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_modulo_crear_para_tesis($1, $2, $3)',
      [user.usuario_id, tesisId, dto.moduloListaId],
    );

    return { ok: true, data: result.rows[0] };
  }

  async actualizar(
    user: CurrentUser,
    moduloId: string,
    dto: ActualizarModuloDto,
  ) {
    const result = await this.databaseService.query<{ ok: boolean }>(
      'SELECT * FROM "AT".fn_modulo_actualizar_estado($1, $2, $3, $4, $5)',
      [
        user.usuario_id,
        moduloId,
        dto.estado,
        dto.progreso ?? null,
        dto.observacion ?? null,
      ],
    );

    return { ok: result.rows[0]?.ok ?? false, data: result.rows[0] };
  }
}
