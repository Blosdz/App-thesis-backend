import { Injectable } from '@nestjs/common';
import { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { GoogleCalendarService } from '../google/google-calendar.service';
import { AprobarPagoReservaDto } from './dto/aprobar-pago-reserva.dto';
import { CancelarReunionDto } from './dto/cancelar-reunion.dto';
import { CrearReunionDto } from './dto/crear-reunion.dto';
import { HistorialValidacionesDto } from './dto/historial-validaciones.dto';
import { ListarReunionesDto } from './dto/listar-reuniones.dto';
import { ResponderReservaDto } from './dto/responder-reserva.dto';
import { ValidarCitaAdminDto } from './dto/validar-cita-admin.dto';

@Injectable()
export class ReunionesService {
  constructor(
    private readonly databaseService: DatabaseService,
    private readonly googleCalendarService: GoogleCalendarService,
  ) {}

  async listar(user: CurrentUser, dto: ListarReunionesDto) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_reunion_listar_por_usuario($1, $2, $3)',
      [user.usuario_id, dto.fechaInicio ?? null, dto.fechaFin ?? null],
    );

    return { ok: true, data: result.rows };
  }

  async crear(user: CurrentUser, dto: CrearReunionDto) {
    const result = await this.databaseService.queryWithUser<{
      data: Record<string, unknown>;
    }>(
      user.auth_usuario_id,
      'SELECT * FROM "AT".fn_reunion_crear($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)',
      [
        user.usuario_id,
        dto.disponibilidadId,
        dto.inicio,
        dto.fin,
        dto.tesisId ?? null,
        dto.motivo ?? null,
        dto.modalidad ?? 'virtual',
        dto.lugar ?? null,
        dto.enlaceReunion ?? null,
        dto.notas ?? null,
      ],
    );

    return { ok: true, data: result.rows[0] };
  }

  async cancelar(
    user: CurrentUser,
    reunionId: string,
    dto: CancelarReunionDto,
  ) {
    const result = await this.databaseService.queryWithUser<{ ok: boolean }>(
      user.auth_usuario_id,
      'SELECT * FROM "AT".fn_reunion_cancelar($1, $2)',
      [reunionId, dto.motivo ?? null],
    );

    return { ok: result.rows[0]?.ok ?? false, data: result.rows[0] };
  }

  async historialEstudiante(
    user: CurrentUser,
    query: HistorialValidacionesDto,
  ) {
    const result = await this.databaseService.queryWithUser<{ ok: boolean }>(
      user.auth_usuario_id,
      'SELECT * FROM "AT".obtener_historial_validaciones_cita_estudiante($1)',
      [query.status ?? null],
    );

    return { ok: true, data: result.rows };
  }

  async historialAsesor(user: CurrentUser, query: HistorialValidacionesDto) {
    const result = await this.databaseService.queryWithUser<{
      data: Record<string, unknown>;
    }>(
      user.auth_usuario_id,
      'SELECT * FROM "AT".obtener_historial_validaciones_cita_asesor($1)',
      [query.status ?? null],
    );

    return { ok: true, data: result.rows };
  }

  async responderReserva(
    user: CurrentUser,
    validationCitaId: string,
    dto: ResponderReservaDto,
  ) {
    const result = await this.databaseService.queryWithUser<{
      data: Record<string, unknown>;
    }>(
      user.auth_usuario_id,
      'SELECT "AT".responder_reserva_cita($1, $2) AS data',
      [validationCitaId, dto.accion],
    );

    return { ok: true, data: result.rows[0]?.data };
  }

  async aprobarPagoReserva(
    user: CurrentUser,
    validationCitaId: string,
    dto: AprobarPagoReservaDto,
  ) {
    const result = await this.databaseService.queryWithUser<{ ok: boolean }>(
      user.auth_usuario_id,
      'SELECT * FROM "AT".aprobar_pago_reserva_cita($1, $2, $3, $4)',
      [
        validationCitaId,
        dto.enlaceReunion ?? null,
        dto.lugar ?? null,
        dto.notas ?? null,
      ],
    );

    return { ok: result.rows[0]?.ok ?? false, data: result.rows[0] };
  }

  async validarCitaAdmin(validationCitaId: string, dto: ValidarCitaAdminDto) {
    const result = await this.databaseService.query<{ ok: boolean }>(
      'SELECT * FROM "AT".validar_cita_asesoria_admin($1, $2, $3, $4)',
      [
        validationCitaId,
        dto.aprobado,
        dto.notasAdmin ?? null,
        dto.enlaceReunion ?? null,
      ],
    );

    return { ok: result.rows[0]?.ok ?? false, data: result.rows[0] };
  }

  async crearMeet(user: CurrentUser, reunionId: string) {
    const reunionResult = await this.databaseService.query<{
      inicio: string;
      fin: string;
      motivo: string | null;
      asesor_email: string;
      estudiante_email: string;
    }>('SELECT * FROM "AT".fn_reunion_obtener_para_meet($1, $2)', [
      user.usuario_id,
      reunionId,
    ]);
    const reunion = reunionResult.rows[0];

    const event = await this.googleCalendarService.createMeetEvent({
      summary: `Reunión de asesoría ${reunionId}`,
      description: reunion?.motivo ?? null,
      start: reunion?.inicio,
      end: reunion?.fin,
      attendees: [reunion?.asesor_email, reunion?.estudiante_email].filter(
        Boolean,
      ),
    });

    const meetLink =
      event.hangoutLink ?? event.conferenceData?.entryPoints?.[0]?.uri;
    const meetCode = event.conferenceData?.conferenceId ?? null;

    const saveResult = await this.databaseService.query(
      'SELECT * FROM "AT".fn_reunion_guardar_meet($1, $2, $3, $4, $5)',
      [reunionId, event.id, meetLink ?? null, meetCode, null],
    );

    return { ok: true, data: { event, reunion: saveResult.rows[0] } };
  }
}
