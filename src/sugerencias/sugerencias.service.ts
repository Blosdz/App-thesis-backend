import { Injectable } from '@nestjs/common';
import { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { CrearSugerenciaDto } from './dto/crear-sugerencia.dto';
import { MarcarSugerenciaDto } from './dto/marcar-sugerencia.dto';
import { ValidarSugerenciaDto } from './dto/validar-sugerencia.dto';

@Injectable()
export class SugerenciasService {
  constructor(private readonly databaseService: DatabaseService) {}

  async crear(user: CurrentUser, dto: CrearSugerenciaDto) {
    const sql = dto.tipoSugerenciaId
      ? 'SELECT * FROM "AT".crear_sugerencia_asesor($1, $2, $3, $4)'
      : 'SELECT * FROM "AT".crear_sugerencia_asesor($1, $2, $3)';
    const params = dto.tipoSugerenciaId
      ? [
          dto.tesisId,
          dto.documentoTesisId ?? null,
          dto.tipoSugerenciaId,
          dto.detalle,
        ]
      : [dto.tesisId, dto.documentoTesisId ?? null, dto.detalle];

    const result = await this.databaseService.queryWithUser(
      user.auth_usuario_id,
      sql,
      params,
    );

    return { ok: true, data: result.rows[0] };
  }

  async listar(tesisId: string) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".listar_sugerencias_tesis($1)',
      [tesisId],
    );

    return { ok: true, data: result.rows };
  }

  async marcar(
    user: CurrentUser,
    sugerenciaId: string,
    dto: MarcarSugerenciaDto,
  ) {
    const result = await this.databaseService.queryWithUser<{
      data: Record<string, unknown>;
    }>(
      user.auth_usuario_id,
      'SELECT * FROM "AT".marcar_sugerencia_aplicada_estudiante($1, $2)',
      [sugerenciaId, dto.aplicado],
    );

    return { ok: true, data: result.rows[0] };
  }

  async validar(
    user: CurrentUser,
    historialSugerenciaId: string,
    dto: ValidarSugerenciaDto,
  ) {
    const result = await this.databaseService.queryWithUser<{
      data: Record<string, unknown>;
    }>(
      user.auth_usuario_id,
      'SELECT "AT".validar_aplicacion_sugerencia($1, $2, $3) AS data',
      [historialSugerenciaId, dto.aprobado, dto.comentarioAsesor ?? null],
    );

    return { ok: true, data: result.rows[0]?.data };
  }
}
