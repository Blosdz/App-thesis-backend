import {
  BadRequestException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { JwtService } from '@nestjs/jwt';
import { DatabaseService } from '../database/database.service';
import { CurrentUser } from '../common/interfaces/current-user.interface';
import { CreateInvitationDto } from './dto/create-invitation.dto';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { ResetPasswordConfirmDto } from './dto/reset-password-confirm.dto';
import { ResetPasswordRequestDto } from './dto/reset-password-request.dto';

export interface AuthUsuarioRow {
  auth_usuario_id: string;
  usuario_id: string;
  email: string;
  rol: CurrentUser['rol'];
  verificado: boolean;
  email_verificado: boolean;
  activo: boolean;
}

export interface ChangePasswordRow {
  ok: boolean;
  message: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly databaseService: DatabaseService,
    private readonly jwtService: JwtService,
  ) {}

  async register(dto: RegisterDto) {
    try {
      const result = await this.databaseService.query<AuthUsuarioRow>(
        'SELECT * FROM "AT".fn_auth_crear_usuario($1, $2, $3)',
        [dto.email, dto.rol, dto.contrasena ?? 'app_theseis'],
      );

      return {
        ok: true,
        message: 'Usuario creado correctamente',
        data: this.toSafeUser(result.rows[0]),
      };
    } catch (error) {
      throw new BadRequestException(this.getDbMessage(error));
    }
  }

  async login(dto: LoginDto) {
    const result = await this.databaseService.query<AuthUsuarioRow>(
      'SELECT * FROM "AT".fn_auth_login_usuario($1, $2)',
      [dto.email, dto.contrasena],
    );

    if (result.rows.length === 0) {
      throw new UnauthorizedException('Credenciales incorrectas');
    }

    const usuario = result.rows[0];
    const payload: CurrentUser = {
      usuario_id: usuario.usuario_id,
      auth_usuario_id: usuario.auth_usuario_id,
      rol: usuario.rol,
    };

    return {
      ok: true,
      token: await this.jwtService.signAsync(payload),
      usuario: this.toSafeUser(usuario),
    };
  }

  async changePassword(user: CurrentUser, dto: ChangePasswordDto) {
    const result = await this.databaseService.query<ChangePasswordRow>(
      'SELECT * FROM "AT".fn_auth_cambiar_contrasena($1, $2, $3)',
      [user.auth_usuario_id, dto.contrasenaActual, dto.contrasenaNueva],
    );
    const response = result.rows[0];

    if (!response?.ok) {
      throw new UnauthorizedException(
        response?.message ?? 'No se pudo cambiar la contraseña',
      );
    }

    return response;
  }

  async requestPasswordReset(dto: ResetPasswordRequestDto) {
    const result = await this.databaseService.query<AuthUsuarioRow>(
      'SELECT * FROM "AT".fn_auth_login_usuario($1, $2)',
      [dto.email, randomUUID()],
    );
    void result;

    const token = await this.jwtService.signAsync({
      email: dto.email.toLowerCase().trim(),
      purpose: 'password_reset',
    });

    return {
      ok: true,
      message: 'Si el correo existe, se generó una solicitud de recuperación',
      resetToken: token,
    };
  }

  async confirmPasswordReset(dto: ResetPasswordConfirmDto) {
    const payload = await this.jwtService.verifyAsync<{
      email: string;
      purpose: string;
    }>(dto.token);

    if (payload.purpose !== 'password_reset') {
      throw new UnauthorizedException('Token de recuperación inválido');
    }

    const userResult = await this.databaseService.query<AuthUsuarioRow>(
      'SELECT au.id AS auth_usuario_id, u.id AS usuario_id, au.email, u.rol, u.verificado, au.email_verificado, au.activo FROM "AT".auth_usuarios au JOIN "AT".usuarios u ON u.auth_usuario_id = au.id WHERE au.email = $1 AND au.activo = true',
      [payload.email],
    );

    if (userResult.rows.length === 0) {
      throw new UnauthorizedException('Token de recuperación inválido');
    }

    const result = await this.databaseService.query<ChangePasswordRow>(
      'SELECT * FROM "AT".fn_auth_reset_contrasena($1, $2)',
      [userResult.rows[0].auth_usuario_id, dto.contrasenaNueva],
    );

    return result.rows[0];
  }

  async createInvitation(dto: CreateInvitationDto) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_auth_crear_invitacion($1, $2, $3)',
      [dto.email, dto.nombre ?? null, dto.payload ?? {}],
    );

    return { ok: true, data: result.rows[0] };
  }

  private toSafeUser(usuario: AuthUsuarioRow) {
    return {
      id: usuario.usuario_id,
      auth_usuario_id: usuario.auth_usuario_id,
      email: usuario.email,
      rol: usuario.rol,
      verificado: usuario.verificado,
      email_verificado: usuario.email_verificado,
      activo: usuario.activo,
    };
  }

  private getDbMessage(error: unknown) {
    return error instanceof Error ? error.message : 'Error de base de datos';
  }
}
