import { Injectable } from '@nestjs/common';
import { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { CrearObservacionDto } from './dto/crear-observacion.dto';

@Injectable()
export class ObservacionesService {
  constructor(private readonly databaseService: DatabaseService) {}

  async crear(user: CurrentUser, dto: CrearObservacionDto) {
    const result = await this.databaseService.queryWithUser(
      user.auth_usuario_id,
      'SELECT * FROM "AT".crear_observacion_tesis_enriquecida($1, $2, $3, $4, $5, $6, $7, $8, $9)',
      [
        dto.tesisId,
        dto.documentoTesisId ?? null,
        dto.reunionId ?? null,
        dto.validationCitaId ?? null,
        dto.titulo ?? null,
        dto.texto ?? null,
        dto.contenidoHtml ?? null,
        dto.contenidoDelta ?? null,
        dto.tipoOrigen ?? 'manual',
      ],
    );

    return { ok: true, data: result.rows[0] };
  }

  async historial(tesisId: string) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".listar_historial_observaciones_tesis($1)',
      [tesisId],
    );

    return { ok: true, data: result.rows };
  }
}
