import { Injectable } from '@nestjs/common';
import { DatabaseService } from '../database/database.service';
import { RegistrarLeadDto } from './dto/registrar-lead.dto';

@Injectable()
export class LeadsService {
  constructor(private readonly databaseService: DatabaseService) {}

  async registrarEstudiante(dto: RegistrarLeadDto) {
    const result = await this.databaseService.query(
      `INSERT INTO "AT".leads_estudiantes
         (telefono, nombre, email, nivel_academico, tipo_tesis_codigo,
          requiere_analisis_estadistico, plan_recomendado_id, precio_cotizado, metadata)
       VALUES ($1, $2, lower($3), $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [
        dto.telefono ?? null,
        dto.nombre ?? null,
        dto.email ?? null,
        dto.nivelAcademico ?? null,
        dto.tipoTesisCodigo ?? null,
        dto.requiereAnalisisEstadistico ?? null,
        dto.planRecomendadoId ?? null,
        dto.precioCotizado ?? null,
        dto.metadata ?? {},
      ],
    );
    return {
      ok: true,
      message: 'Lead registrado correctamente',
      data: result.rows[0],
    };
  }
}
