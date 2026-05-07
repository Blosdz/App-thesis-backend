import { Injectable, NotFoundException } from '@nestjs/common';
import { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { GuardarPerfilAsesorDto } from './dto/guardar-perfil-asesor.dto';
import { GuardarPerfilEstudianteDto } from './dto/guardar-perfil-estudiante.dto';

@Injectable()
export class UsuariosService {
  constructor(private readonly databaseService: DatabaseService) {}

  async me(user: CurrentUser) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_usuario_obtener_actual($1)',
      [user.auth_usuario_id],
    );

    if (result.rows.length === 0) {
      throw new NotFoundException('Usuario no encontrado');
    }

    return { ok: true, data: result.rows[0] };
  }

  async guardarPerfilEstudiante(
    user: CurrentUser,
    dto: GuardarPerfilEstudianteDto,
  ) {
    const result = await this.databaseService.queryWithUser(
      user.auth_usuario_id,
      'SELECT * FROM "AT".guardar_perfil_estudiante($1, $2, $3, $4, $5, $6)',
      [
        dto.nombres,
        dto.apellidos,
        dto.universidadId,
        dto.carrera,
        dto.dni,
        dto.telefono ?? null,
      ],
    );

    return { ok: true, data: result.rows[0] };
  }

  async guardarPerfilAsesor(user: CurrentUser, dto: GuardarPerfilAsesorDto) {
    const result = await this.databaseService.queryWithUser(
      user.auth_usuario_id,
      'SELECT * FROM "AT".guardar_perfil_asesor($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)',
      [
        dto.nombreMostrar,
        dto.universidadId,
        dto.slug,
        dto.emailPublico,
        dto.biografia,
        dto.fotoUrl ?? null,
        dto.especialidadId,
        dto.carrera,
        dto.nivelAcademico,
        dto.nombres,
        dto.apellidos,
        dto.dni,
        dto.telefono ?? null,
      ],
    );

    return { ok: true, data: result.rows[0] };
  }
}
