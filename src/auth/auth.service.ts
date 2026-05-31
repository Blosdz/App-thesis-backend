import {
  BadRequestException,
  Injectable,
  InternalServerErrorException,
  Logger,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { createHash, randomBytes } from 'crypto';
import { QueryResultRow } from 'pg';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { EmailService } from '../email/email.service';
import { ChangePasswordDto } from './dto/change-password.dto';
import { LoginDto } from './dto/login.dto';
import {
  PasswordResetDto,
  PasswordResetRequestDto,
} from './dto/password-reset.dto';
import { RegisterDto } from './dto/register.dto';

export interface JwtPayload {
  sub: string;
  auth_usuario_id: string;
  email: string;
  rol: CurrentUser['rol'];
}

interface UserRow extends QueryResultRow, CurrentUser {}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly databaseService: DatabaseService,
    private readonly jwtService: JwtService,
    private readonly emailService: EmailService,
  ) {}

  async register(dto: RegisterDto) {
    try {
      if (!this.emailService.isConfigured()) {
        throw new ServiceUnavailableException(
          'El servicio de correo no está configurado. No se puede crear la cuenta sin enviar el enlace de verificación.',
        );
      }

      const password = dto.contrasena ?? 'app_theseis';
      await this.ensureEmailVerificationTable();
      const usuario = await this.databaseService.withTransaction(
        async (client) => {
          const authResult = await client.query<{
            id: string;
            email: string;
            email_verificado: boolean;
          }>(
            `INSERT INTO "AT".auth_usuarios (email, contrasena_hash)
           VALUES (lower($1), crypt($2, gen_salt('bf', 12)))
           RETURNING id, email, email_verificado`,
            [dto.email, password],
          );

          const usuarioResult = await client.query<UserRow>(
            `INSERT INTO "AT".usuarios (auth_usuario_id, rol)
           VALUES ($1, $2)
           RETURNING id AS usuario_id, auth_usuario_id, rol, verificado`,
            [authResult.rows[0].id, dto.rol],
          );

          return {
            ...usuarioResult.rows[0],
            email: authResult.rows[0].email,
            email_verificado: authResult.rows[0].email_verificado,
          };
        },
      );
      const verification = await this.createEmailVerificationToken(
        usuario.auth_usuario_id,
      );
      const emailResult = await this.emailService.sendVerificationEmail({
        to: usuario.email,
        verificationUrl: verification.url,
      });
      if (!emailResult.ok) {
        await this.deleteCreatedRegistration(usuario.auth_usuario_id);
        throw new ServiceUnavailableException(
          'No se pudo enviar el correo de verificación. La cuenta no fue creada.',
        );
      }

      return {
        ok: true,
        message:
          'Usuario creado correctamente. Revisa tu correo para verificar la cuenta.',
        email_sent: true,
        usuario: this.publicUser(usuario),
        verification_url: verification.devUrl,
      };
    } catch (error) {
      this.logger.error('Error al registrar usuario', error);
      if (this.isPgError(error, '23505')) {
        throw new BadRequestException('El email ya está registrado');
      }
      if (error instanceof ServiceUnavailableException) {
        throw error;
      }
      throw new InternalServerErrorException('No se pudo crear el usuario');
    }
  }

  async login(dto: LoginDto) {
    const result = await this.databaseService.query<UserRow>(
      `SELECT
         au.id AS auth_usuario_id,
         u.id AS usuario_id,
         au.email,
         u.rol,
         u.verificado,
         au.email_verificado
       FROM "AT".auth_usuarios au
       JOIN "AT".usuarios u ON u.auth_usuario_id = au.id
       WHERE au.email = lower($1)
         AND au.activo = true
         AND au.contrasena_hash = crypt($2, au.contrasena_hash)
       LIMIT 1`,
      [dto.email, dto.contrasena],
    );

    const usuario = result.rows[0];
    if (!usuario) {
      throw new UnauthorizedException('Credenciales inválidas');
    }

    await this.databaseService.query(
      `UPDATE "AT".auth_usuarios
       SET ultimo_login_en = now(), actualizado_en = now()
       WHERE id = $1`,
      [usuario.auth_usuario_id],
    );

    return {
      ok: true,
      token: this.signToken(usuario),
      usuario: this.publicUser(usuario),
    };
  }

  async me(user: CurrentUser) {
    return {
      ok: true,
      usuario: this.publicUser(user),
    };
  }

  async changePassword(user: CurrentUser, dto: ChangePasswordDto) {
    const result = await this.databaseService.query(
      `UPDATE "AT".auth_usuarios
       SET contrasena_hash = crypt($2, gen_salt('bf', 12)), actualizado_en = now()
       WHERE id = $1
         AND contrasena_hash = crypt($3, contrasena_hash)`,
      [user.auth_usuario_id, dto.contrasenaNueva, dto.contrasenaActual],
    );

    if (result.rowCount === 0) {
      throw new UnauthorizedException('La contraseña actual no es correcta');
    }

    return { ok: true, message: 'Contraseña actualizada correctamente' };
  }

  async requestPasswordReset(dto: PasswordResetRequestDto) {
    await this.ensurePasswordResetTable();

    const userResult = await this.databaseService.query<{
      id: string;
      email: string;
    }>(
      `SELECT id, email
       FROM "AT".auth_usuarios
       WHERE email = lower($1) AND activo = true
       LIMIT 1`,
      [dto.email],
    );

    const token = randomBytes(32).toString('hex');
    const tokenHash = this.hashToken(token);

    if (userResult.rows[0]) {
      await this.databaseService.query(
        `INSERT INTO "AT".password_reset_tokens
           (auth_usuario_id, token_hash, expira_en)
         VALUES ($1, $2, now() + interval '1 hour')`,
        [userResult.rows[0].id, tokenHash],
      );
    }

    return {
      ok: true,
      message:
        'Si el correo está registrado, se generó una solicitud de recuperación.',
      token: userResult.rows[0] ? token : null,
    };
  }

  async resetPassword(dto: PasswordResetDto) {
    await this.ensurePasswordResetTable();

    const tokenHash = this.hashToken(dto.token);
    const result = await this.databaseService.withTransaction(async (client) => {
      const tokenResult = await client.query<{
        id: string;
        auth_usuario_id: string;
      }>(
        `SELECT id, auth_usuario_id
         FROM "AT".password_reset_tokens
         WHERE token_hash = $1
           AND usado_en IS NULL
           AND expira_en > now()
         ORDER BY creado_en DESC
         LIMIT 1
         FOR UPDATE`,
        [tokenHash],
      );

      const row = tokenResult.rows[0];
      if (!row) {
        throw new BadRequestException('Token inválido o expirado');
      }

      await client.query(
        `UPDATE "AT".auth_usuarios
         SET contrasena_hash = crypt($2, gen_salt('bf', 12)),
             actualizado_en = now()
         WHERE id = $1`,
        [row.auth_usuario_id, dto.contrasenaNueva],
      );

      await client.query(
        `UPDATE "AT".password_reset_tokens
         SET usado_en = now()
         WHERE id = $1`,
        [row.id],
      );

      return true;
    });

    return {
      ok: result,
      message: 'Contraseña restablecida correctamente',
    };
  }

  async verifyEmail(token: string) {
    if (!token) {
      throw new BadRequestException('Token requerido');
    }

    await this.ensureEmailVerificationTable();

    const tokenHash = this.hashToken(token);
    const result = await this.databaseService.withTransaction(async (client) => {
      const tokenResult = await client.query<{
        id: string;
        auth_usuario_id: string;
      }>(
        `SELECT id, auth_usuario_id
         FROM "AT".email_verification_tokens
         WHERE token_hash = $1
           AND usado_en IS NULL
           AND expira_en > now()
         ORDER BY creado_en DESC
         LIMIT 1
         FOR UPDATE`,
        [tokenHash],
      );

      const row = tokenResult.rows[0];
      if (!row) {
        throw new BadRequestException('Token inválido o expirado');
      }

      await client.query(
        `UPDATE "AT".auth_usuarios
         SET email_verificado = true, actualizado_en = now()
         WHERE id = $1`,
        [row.auth_usuario_id],
      );

      await client.query(
        `UPDATE "AT".email_verification_tokens
         SET usado_en = now()
         WHERE id = $1`,
        [row.id],
      );

      return true;
    });

    return {
      ok: result,
      message: 'Correo verificado correctamente',
    };
  }

  async validatePayload(payload: JwtPayload): Promise<CurrentUser | null> {
    const result = await this.databaseService.query<UserRow>(
      `SELECT
         au.id AS auth_usuario_id,
         u.id AS usuario_id,
         au.email,
         u.rol,
         u.verificado,
         au.email_verificado
       FROM "AT".auth_usuarios au
       JOIN "AT".usuarios u ON u.auth_usuario_id = au.id
       WHERE au.id = $1
         AND u.id = $2
         AND au.activo = true
       LIMIT 1`,
      [payload.auth_usuario_id, payload.sub],
    );

    return result.rows[0] ?? null;
  }

  private signToken(user: CurrentUser): string {
    return this.jwtService.sign({
      sub: user.usuario_id,
      auth_usuario_id: user.auth_usuario_id,
      email: user.email,
      rol: user.rol,
    });
  }

  private publicUser(user: CurrentUser) {
    return {
      id: user.usuario_id,
      auth_usuario_id: user.auth_usuario_id,
      email: user.email,
      rol: user.rol,
      verificado: user.verificado,
      email_verificado: user.email_verificado,
    };
  }

  private isPgError(error: unknown, code: string): boolean {
    return (
      typeof error === 'object' &&
      error !== null &&
      'code' in error &&
      error.code === code
    );
  }

  private hashToken(token: string) {
    return createHash('sha256').update(token).digest('hex');
  }

  private async ensurePasswordResetTable() {
    await this.databaseService.query(
      `CREATE TABLE IF NOT EXISTS "AT".password_reset_tokens (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        auth_usuario_id uuid NOT NULL REFERENCES "AT".auth_usuarios(id) ON DELETE CASCADE,
        token_hash text NOT NULL,
        expira_en timestamptz NOT NULL,
        usado_en timestamptz NULL,
        creado_en timestamptz NOT NULL DEFAULT now()
      )`,
    );
    await this.databaseService.query(
      `CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_hash
       ON "AT".password_reset_tokens (token_hash)`,
    );
  }

  private async ensureEmailVerificationTable() {
    await this.databaseService.query(
      `CREATE TABLE IF NOT EXISTS "AT".email_verification_tokens (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
        auth_usuario_id uuid NOT NULL REFERENCES "AT".auth_usuarios(id) ON DELETE CASCADE,
        token_hash text NOT NULL,
        expira_en timestamptz NOT NULL,
        usado_en timestamptz NULL,
        creado_en timestamptz NOT NULL DEFAULT now()
      )`,
    );
    await this.databaseService.query(
      `CREATE INDEX IF NOT EXISTS idx_email_verification_tokens_hash
       ON "AT".email_verification_tokens (token_hash)`,
    );
  }

  private async createEmailVerificationToken(authUsuarioId: string) {
    const token = randomBytes(32).toString('hex');
    const tokenHash = this.hashToken(token);

    await this.databaseService.query(
      `INSERT INTO "AT".email_verification_tokens
         (auth_usuario_id, token_hash, expira_en)
       VALUES ($1, $2, now() + interval '24 hours')`,
      [authUsuarioId, tokenHash],
    );

    const frontendUrl = (
      process.env.FRONTEND_URL ||
      process.env.APP_URL ||
      'http://localhost:5173'
    ).replace(/\/$/, '');
    const url = `${frontendUrl}/#/verify-email?token=${token}`;

    return {
      url,
      devUrl: process.env.NODE_ENV === 'production' ? undefined : url,
    };
  }

  private async deleteCreatedRegistration(authUsuarioId: string) {
    await this.databaseService.withTransaction(async (client) => {
      await client.query(
        `DELETE FROM "AT".email_verification_tokens
         WHERE auth_usuario_id = $1`,
        [authUsuarioId],
      );
      await client.query(
        `DELETE FROM "AT".usuarios
         WHERE auth_usuario_id = $1`,
        [authUsuarioId],
      );
      await client.query(
        `DELETE FROM "AT".auth_usuarios
         WHERE id = $1
           AND email_verificado = false
           AND ultimo_login_en IS NULL`,
        [authUsuarioId],
      );
    });
  }
}
