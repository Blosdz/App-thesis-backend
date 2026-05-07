import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { RegistrarLeadDto } from './dto/registrar-lead.dto';

@Injectable()
export class LeadsService {
  constructor(private readonly databaseService: DatabaseService) {}

  async registrar(dto: RegistrarLeadDto) {
    const result = await this.databaseService.query<{
      data: Record<string, unknown>;
    }>(
      'SELECT "AT".registrar_lead_estudiante($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) AS data',
      [
        dto.telefono,
        dto.nombre ?? null,
        dto.email ?? null,
        dto.nivelAcademico ?? null,
        dto.tipoTesisCodigo ?? null,
        dto.requiereAnalisisEstadistico ?? null,
        dto.planRecomendadoId ?? null,
        dto.precioCotizado ?? null,
        'nuevo',
        dto.metadata ?? {},
      ],
    );

    return { ok: true, data: result.rows[0]?.data };
  }
}
