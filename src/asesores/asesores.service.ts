import { Injectable } from '@nestjs/common';
import { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { AsignarTesisAsesorDto } from './dto/asignar-tesis-asesor.dto';
import { BloquesDisponiblesDto } from './dto/bloques-disponibles.dto';
import { CambiarEstadoRelacionDto } from './dto/cambiar-estado-relacion.dto';
import { CrearEspacioLibreDto } from './dto/crear-espacio-libre.dto';
import { VincularAsesorDto } from './dto/vincular-asesor.dto';

@Injectable()
export class AsesoresService {
  constructor(private readonly databaseService: DatabaseService) {}

  async listar() {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".obtener_asesores()',
    );

    return { ok: true, data: result.rows };
  }

  async vincularPorSlug(user: CurrentUser, dto: VincularAsesorDto) {
    const result = await this.databaseService.queryWithUser(
      user.auth_usuario_id,
      'SELECT * FROM "AT".vincularme_con_asesor_por_slug($1)',
      [dto.valor],
    );

    return { ok: true, data: result.rows[0] };
  }

  async vincularPorCodigo(user: CurrentUser, dto: VincularAsesorDto) {
    const result = await this.databaseService.queryWithUser(
      user.auth_usuario_id,
      'SELECT * FROM "AT".vincularme_con_asesor_por_codigo($1)',
      [dto.valor],
    );

    return { ok: true, data: result.rows[0] };
  }

  async generarCodigo(user: CurrentUser) {
    const result = await this.databaseService.queryWithUser(
      user.auth_usuario_id,
      'SELECT * FROM "AT".generar_codigo_publico_asesor()',
    );

    return { ok: true, data: result.rows[0] };
  }

  async obtenerCodigo(user: CurrentUser) {
    const result = await this.databaseService.queryWithUser(
      user.auth_usuario_id,
      'SELECT * FROM "AT".obtener_mi_codigo_publico_asesor()',
    );

    return { ok: true, data: result.rows[0] ?? null };
  }

  async misAsesores(user: CurrentUser) {
    const result = await this.databaseService.queryWithUser(
      user.auth_usuario_id,
      'SELECT * FROM "AT".obtener_mis_asesores()',
    );

    return { ok: true, data: result.rows };
  }

  async misEstudiantes(user: CurrentUser) {
    const result = await this.databaseService.queryWithUser(
      user.auth_usuario_id,
      'SELECT * FROM "AT".obtener_estudiantes_mis_asesorias()',
    );

    return { ok: true, data: result.rows };
  }

  async cambiarEstadoRelacion(
    relacionId: string,
    dto: CambiarEstadoRelacionDto,
  ) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_asesor_cambiar_estado_relacion($1, $2)',
      [relacionId, dto.estado],
    );

    return { ok: true, data: result.rows[0] };
  }

  async asignarTesis(user: CurrentUser, dto: AsignarTesisAsesorDto) {
    const result = await this.databaseService.queryWithUser(
      user.auth_usuario_id,
      'SELECT * FROM "AT".asignar_mi_tesis_a_asesor($1, $2, $3)',
      [dto.tesisId, dto.asesorId, dto.rol ?? 'principal'],
    );

    return { ok: true, data: result.rows[0] };
  }

  async crearEspacioLibre(user: CurrentUser, dto: CrearEspacioLibreDto) {
    const result = await this.databaseService.queryWithUser(
      user.auth_usuario_id,
      'SELECT * FROM "AT".crear_espacio_libre_asesor($1, $2, $3, $4, $5, $6, $7, $8)',
      [
        dto.inicio,
        dto.fin,
        dto.usaBloques ?? true,
        dto.duracionBloqueMinutos ?? 30,
        dto.recurrente ?? false,
        dto.diasSemana ?? null,
        dto.fechaInicio ?? null,
        dto.fechaFin ?? null,
      ],
    );

    return { ok: true, data: result.rows };
  }

  async listarEspaciosLibres(user: CurrentUser) {
    const result = await this.databaseService.queryWithUser(
      user.auth_usuario_id,
      'SELECT * FROM "AT".obtener_mis_espacios_libres_asesor()',
    );

    return { ok: true, data: result.rows };
  }

  async desactivarEspacioLibre(user: CurrentUser, disponibilidadId: string) {
    const result = await this.databaseService.queryWithUser(
      user.auth_usuario_id,
      'SELECT * FROM "AT".desactivar_espacio_libre_asesor($1)',
      [disponibilidadId],
    );

    return { ok: true, data: result.rows[0] };
  }

  async bloquesDisponibles(query: BloquesDisponiblesDto) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".obtener_bloques_disponibles_asesor($1, $2, $3)',
      [query.asesorId, query.desde, query.hasta],
    );

    return { ok: true, data: result.rows };
  }
}
