import { ForbiddenException, Injectable } from '@nestjs/common';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { CrearObservacionDto } from './dto/crear-observacion.dto';

@Injectable()
export class ObservacionesService {
  constructor(private readonly databaseService: DatabaseService) {}

  async crear(user: CurrentUser, dto: CrearObservacionDto) {
    if (user.rol !== 'asesor' && user.rol !== 'admin') {
      throw new ForbiddenException(
        'Esta operación requiere rol asesor o admin',
      );
    }
    const result = await this.databaseService.query(
      `INSERT INTO "AT".observaciones_tesis
         (tesis_id, documento_tesis_id, asesor_id, texto, titulo, contenido_html, contenido_delta)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [
        dto.tesisId,
        dto.documentoTesisId ?? null,
        user.usuario_id,
        dto.texto,
        dto.titulo ?? null,
        dto.contenidoHtml ?? null,
        dto.contenidoDelta ?? null,
      ],
    );
    return {
      ok: true,
      message: 'Observación registrada correctamente',
      data: result.rows[0],
    };
  }

  async historial(tesisId: string) {
    const result = await this.databaseService.query(
      `SELECT o.*, ppa.nombre_mostrar AS asesor_nombre
       FROM "AT".observaciones_tesis o
       LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = o.asesor_id
       WHERE o.tesis_id = $1
       ORDER BY o.creado_en DESC`,
      [tesisId],
    );
    return { ok: true, data: result.rows };
  }
}
