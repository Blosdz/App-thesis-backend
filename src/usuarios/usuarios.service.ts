import {
  BadRequestException,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { plainToInstance } from 'class-transformer';
import { validate, ValidationError } from 'class-validator';
import { PoolClient } from 'pg';
import { CryptoService } from '../common/crypto/crypto.service';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { LocalStorageService } from '../storage/local-storage.service';
import { GuardarPerfilAsesorDto } from './dto/guardar-perfil-asesor.dto';
import { GuardarPerfilEstudianteDto } from './dto/guardar-perfil-estudiante.dto';

type StudentProfileRow = {
  estudiante_id: string;
  perfil_id: string | null;
  nombres: string | null;
  apellidos: string | null;
  universidad_id: string | null;
  carrera: string | null;
  foto_url: string | null;
  creado_en: Date | string | null;
  actualizado_en: Date | string | null;
  dni_encriptado: string | null;
  telefono_encriptado: string | null;
};

type AdvisorProfileRow = {
  asesor_id: string;
  perfil_id: string | null;
  nombre_mostrar: string | null;
  universidad_id: string | null;
  slug: string | null;
  email_publico: string | null;
  biografia: string | null;
  foto_url: string | null;
  especialidad_id: string | null;
  carrera: string | null;
  nivel_academico: string | null;
  creado_en: Date | string | null;
  actualizado_en: Date | string | null;
  nombres_encriptados: string | null;
  apellidos_encriptados: string | null;
  dni_encriptado: string | null;
  telefono_encriptado: string | null;
};

@Injectable()
export class UsuariosService {
  constructor(
    private readonly databaseService: DatabaseService,
    private readonly cryptoService: CryptoService,
    private readonly localStorageService: LocalStorageService,
  ) {}

  async obtenerMiPerfil(user: CurrentUser) {
    if (user.rol === 'estudiante') {
      return this.obtenerPerfilEstudiante(user);
    }

    if (user.rol === 'asesor') {
      return this.obtenerPerfilAsesor(user);
    }

    throw new ForbiddenException('Esta operación no está disponible para tu rol');
  }

  async guardarMiPerfil(user: CurrentUser, payload: Record<string, unknown>) {
    if (user.rol === 'estudiante') {
      const dto = await this.validateDto(GuardarPerfilEstudianteDto, payload);
      return this.guardarPerfilEstudiante(user, dto);
    }

    if (user.rol === 'asesor') {
      const dto = await this.validateDto(GuardarPerfilAsesorDto, payload);
      return this.guardarPerfilAsesor(user, dto);
    }

    throw new ForbiddenException('Esta operación no está disponible para tu rol');
  }

  async obtenerPerfilEstudiante(user: CurrentUser) {
    this.requireRole(user, 'estudiante');

    const result = await this.databaseService.query<StudentProfileRow>(
      `SELECT
         u.id AS estudiante_id,
         pe.id AS perfil_id,
         pe.nombres,
         pe.apellidos,
         pe.universidad_id,
         pe.carrera,
         pe.foto_url,
         COALESCE(pe.creado_en, dpe.creado_en) AS creado_en,
         COALESCE(pe.actualizado_en, dpe.actualizado_en) AS actualizado_en,
         dpe.dni_encriptado,
         dpe.telefono_encriptado
       FROM "AT".usuarios u
       LEFT JOIN "AT".perfil_estudiante pe ON pe.estudiante_id = u.id
       LEFT JOIN "AT".datos_privados_estudiante dpe ON dpe.estudiante_id = u.id
       WHERE u.id = $1
       LIMIT 1`,
      [user.usuario_id],
    );

    const perfil = result.rows[0];

    return {
      ok: true,
      data: this.hasStudentProfile(perfil)
        ? this.serializeStudentProfile(perfil)
        : null,
    };
  }

  async guardarPerfilEstudiante(
    user: CurrentUser,
    dto: GuardarPerfilEstudianteDto,
  ) {
    this.requireRole(user, 'estudiante');

    const dniEncriptado = this.cryptoService.encrypt(dto.dni);

    if (!dniEncriptado) {
      throw new BadRequestException('El DNI es obligatorio');
    }

    const telefonoEncriptado = this.cryptoService.encrypt(dto.telefono);

    const perfil = await this.databaseService.withTransaction(
      async (client) => {
        await this.ensureUniversidadExists(client, dto.universidadId);

        const perfilRow = await this.upsertPerfilEstudiante(client, user, dto);
        await this.upsertDatosPrivadosEstudiante(client, user, {
          dniEncriptado,
          telefonoEncriptado,
        });

        return {
          perfil_id: perfilRow.id,
          estudiante_id: perfilRow.estudiante_id,
          nombres: perfilRow.nombres,
          apellidos: perfilRow.apellidos,
          universidad_id: perfilRow.universidad_id,
          carrera: perfilRow.carrera,
          foto_url: perfilRow.foto_url,
          creado_en: perfilRow.creado_en,
          actualizado_en: perfilRow.actualizado_en,
          dni_encriptado: dniEncriptado,
          telefono_encriptado: telefonoEncriptado,
        } satisfies StudentProfileRow;
      },
    );

    return {
      ok: true,
      message: 'Perfil de estudiante guardado correctamente',
      data: this.serializeStudentProfile(perfil),
    };
  }

  async obtenerPerfilAsesor(user: CurrentUser) {
    this.requireRole(user, 'asesor');

    const result = await this.databaseService.query<AdvisorProfileRow>(
      `SELECT
         u.id AS asesor_id,
         ppa.id AS perfil_id,
         ppa.nombre_mostrar,
         ppa.universidad_id,
         ppa.slug,
         ppa.email_publico,
         ppa.biografia,
         ppa.foto_url,
         ppa.especialidad_id,
         ppa.carrera,
         ppa.nivel_academico,
         COALESCE(ppa.creado_en, dpa.creado_en) AS creado_en,
         COALESCE(ppa.actualizado_en, dpa.actualizado_en) AS actualizado_en,
         dpa.nombres_encriptados,
         dpa.apellidos_encriptados,
         dpa.dni_encriptado,
         dpa.telefono_encriptado
       FROM "AT".usuarios u
       LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = u.id
       LEFT JOIN "AT".datos_privados_asesor dpa ON dpa.asesor_id = u.id
       WHERE u.id = $1
       LIMIT 1`,
      [user.usuario_id],
    );

    const perfil = result.rows[0];

    return {
      ok: true,
      data: this.hasAdvisorProfile(perfil)
        ? this.serializeAdvisorProfile(perfil)
        : null,
    };
  }

  async guardarPerfilAsesor(user: CurrentUser, dto: GuardarPerfilAsesorDto) {
    this.requireRole(user, 'asesor');

    const nombreMostrar = dto.nombreMostrar ?? this.buildAdvisorDisplayName(dto);
    if (!nombreMostrar) {
      throw new BadRequestException(
        'No se pudo generar el nombre público del asesor',
      );
    }

    const slug = dto.slug ?? this.slugify(nombreMostrar);
    if (!slug) {
      throw new BadRequestException('El slug público es obligatorio');
    }

    const nombresEncriptados = this.cryptoService.encrypt(dto.nombres);
    const apellidosEncriptados = this.cryptoService.encrypt(dto.apellidos);
    const dniEncriptado = this.cryptoService.encrypt(dto.dni);
    const telefonoEncriptado = this.cryptoService.encrypt(dto.telefono);

    if (!nombresEncriptados || !apellidosEncriptados || !dniEncriptado) {
      throw new BadRequestException(
        'Nombres, apellidos y DNI son obligatorios para el asesor',
      );
    }

    const perfil = await this.databaseService.withTransaction(
      async (client) => {
        await this.ensureUniversidadExists(client, dto.universidadId);
        await this.ensureEspecialidadExists(client, dto.especialidadId);
        await this.ensureUniqueAdvisorSlug(client, user.usuario_id, slug);

        const perfilRow = await this.upsertPerfilPublicoAsesor(client, user, {
          dto,
          nombreMostrar,
          slug,
        });

        await this.upsertDatosPrivadosAsesor(client, user, {
          nombresEncriptados,
          apellidosEncriptados,
          dniEncriptado,
          telefonoEncriptado,
        });

        return {
          perfil_id: perfilRow.id,
          asesor_id: perfilRow.asesor_id,
          nombre_mostrar: perfilRow.nombre_mostrar,
          universidad_id: perfilRow.universidad_id,
          slug: perfilRow.slug,
          email_publico: perfilRow.email_publico,
          biografia: perfilRow.biografia,
          foto_url: perfilRow.foto_url,
          especialidad_id: perfilRow.especialidad_id,
          carrera: perfilRow.carrera,
          nivel_academico: perfilRow.nivel_academico,
          creado_en: perfilRow.creado_en,
          actualizado_en: perfilRow.actualizado_en,
          nombres_encriptados: nombresEncriptados,
          apellidos_encriptados: apellidosEncriptados,
          dni_encriptado: dniEncriptado,
          telefono_encriptado: telefonoEncriptado,
        } satisfies AdvisorProfileRow;
      },
    );

    return {
      ok: true,
      message: 'Perfil de asesor guardado correctamente',
      data: this.serializeAdvisorProfile(perfil),
    };
  }

  async obtenerMiRol(user: CurrentUser) {
    return { ok: true, data: { rol: user.rol, usuario_id: user.usuario_id } };
  }

  async subirFotoPerfil(
    user: CurrentUser,
    file: Express.Multer.File | undefined,
  ) {
    if (user.rol !== 'estudiante' && user.rol !== 'asesor') {
      throw new ForbiddenException('Esta operación no está disponible para tu rol');
    }

    if (!file) {
      throw new BadRequestException('Se requiere file');
    }

    if (!file.mimetype?.startsWith('image/')) {
      throw new BadRequestException('La foto debe ser una imagen');
    }

    if (file.size > 5 * 1024 * 1024) {
      throw new BadRequestException('La foto no debe superar 5MB');
    }

    const savedFile = await this.localStorageService.saveFile(file, {
      directory: `perfiles/${user.rol}/${user.usuario_id}`,
      fileNamePrefix: 'foto-perfil',
    });

    const tableName =
      user.rol === 'asesor' ? 'perfil_publico_asesor' : 'perfil_estudiante';
    const ownerColumn = user.rol === 'asesor' ? 'asesor_id' : 'estudiante_id';

    const updated = await this.databaseService.query(
      `UPDATE "AT".${tableName}
       SET foto_url = $2, actualizado_en = now()
       WHERE ${ownerColumn} = $1
       RETURNING *`,
      [user.usuario_id, savedFile.publicUrl],
    );

    if (!updated.rows[0]) {
      throw new BadRequestException(
        'Primero guarda tu perfil antes de subir una foto',
      );
    }

    return {
      ok: true,
      message: 'Foto de perfil subida correctamente',
      data: {
        foto_url: savedFile.publicUrl,
        ruta_storage: savedFile.relativePath,
      },
    };
  }

  private async upsertPerfilEstudiante(
    client: PoolClient,
    user: CurrentUser,
    dto: GuardarPerfilEstudianteDto,
  ) {
    const existing = await client.query<{ id: string }>(
      `SELECT id
       FROM "AT".perfil_estudiante
       WHERE estudiante_id = $1
       LIMIT 1`,
      [user.usuario_id],
    );

    if (existing.rows[0]) {
      const updated = await client.query(
        `UPDATE "AT".perfil_estudiante
         SET nombres = $2,
             apellidos = $3,
             universidad_id = $4,
             carrera = $5,
             foto_url = COALESCE($6, foto_url),
             actualizado_en = now()
         WHERE id = $1
         RETURNING *`,
        [
          existing.rows[0].id,
          dto.nombres,
          dto.apellidos,
          dto.universidadId ?? null,
          dto.carrera ?? null,
          dto.fotoUrl ?? null,
        ],
      );

      return updated.rows[0];
    }

    const inserted = await client.query(
      `INSERT INTO "AT".perfil_estudiante
         (estudiante_id, nombres, apellidos, universidad_id, carrera, foto_url)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [
        user.usuario_id,
        dto.nombres,
        dto.apellidos,
        dto.universidadId ?? null,
        dto.carrera ?? null,
        dto.fotoUrl ?? null,
      ],
    );

    return inserted.rows[0];
  }

  private async upsertDatosPrivadosEstudiante(
    client: PoolClient,
    user: CurrentUser,
    payload: {
      dniEncriptado: string;
      telefonoEncriptado: string | null;
    },
  ) {
    const existing = await client.query<{ id: string }>(
      `SELECT id
       FROM "AT".datos_privados_estudiante
       WHERE estudiante_id = $1
       LIMIT 1`,
      [user.usuario_id],
    );

    if (existing.rows[0]) {
      await client.query(
        `UPDATE "AT".datos_privados_estudiante
         SET dni_encriptado = $2,
             telefono_encriptado = $3,
             actualizado_en = now()
         WHERE id = $1`,
        [
          existing.rows[0].id,
          payload.dniEncriptado,
          payload.telefonoEncriptado,
        ],
      );
      return;
    }

    await client.query(
      `INSERT INTO "AT".datos_privados_estudiante
         (estudiante_id, dni_encriptado, telefono_encriptado)
       VALUES ($1, $2, $3)`,
      [user.usuario_id, payload.dniEncriptado, payload.telefonoEncriptado],
    );
  }

  private async ensureUniqueAdvisorSlug(
    client: PoolClient,
    asesorId: string,
    slug: string,
  ) {
    const existing = await client.query<{ asesor_id: string }>(
      `SELECT asesor_id
       FROM "AT".perfil_publico_asesor
       WHERE slug = $1
         AND asesor_id <> $2
       LIMIT 1`,
      [slug, asesorId],
    );

    if (existing.rows[0]) {
      throw new BadRequestException(
        'El slug público ya está en uso por otro asesor',
      );
    }
  }

  private async ensureUniversidadExists(
    client: PoolClient,
    universidadId?: string,
  ) {
    if (!universidadId) return;

    const existing = await client.query<{ id: string }>(
      `SELECT id
       FROM "AT".universidades
       WHERE id = $1
       LIMIT 1`,
      [universidadId],
    );

    if (!existing.rows[0]) {
      throw new BadRequestException(
        'La universidad seleccionada no existe en el catálogo',
      );
    }
  }

  private async ensureEspecialidadExists(
    client: PoolClient,
    especialidadId?: string,
  ) {
    if (!especialidadId) return;

    const existing = await client.query<{ id: string }>(
      `SELECT id
       FROM "AT".especialidades
       WHERE id = $1
       LIMIT 1`,
      [especialidadId],
    );

    if (!existing.rows[0]) {
      throw new BadRequestException(
        'La especialidad seleccionada no existe en el catálogo',
      );
    }
  }

  private async upsertPerfilPublicoAsesor(
    client: PoolClient,
    user: CurrentUser,
    payload: {
      dto: GuardarPerfilAsesorDto;
      nombreMostrar: string;
      slug: string;
    },
  ) {
    const existing = await client.query<{ id: string }>(
      `SELECT id
       FROM "AT".perfil_publico_asesor
       WHERE asesor_id = $1
       LIMIT 1`,
      [user.usuario_id],
    );

    const params = [
      payload.nombreMostrar,
      payload.dto.universidadId ?? null,
      payload.slug,
      payload.dto.emailPublico ?? null,
      payload.dto.biografia ?? null,
      payload.dto.fotoUrl ?? null,
      payload.dto.especialidadId ?? null,
      payload.dto.carrera ?? null,
      payload.dto.nivelAcademico ?? null,
    ];

    if (existing.rows[0]) {
      const updated = await client.query(
        `UPDATE "AT".perfil_publico_asesor
         SET nombre_mostrar = $2,
             universidad_id = $3,
             slug = $4,
             email_publico = $5,
             biografia = $6,
             foto_url = $7,
             especialidad_id = $8,
             carrera = $9,
             nivel_academico = $10,
             actualizado_en = now()
         WHERE id = $1
         RETURNING *`,
        [existing.rows[0].id, ...params],
      );

      return updated.rows[0];
    }

    const inserted = await client.query(
      `INSERT INTO "AT".perfil_publico_asesor
         (asesor_id, nombre_mostrar, universidad_id, slug, email_publico, biografia,
          foto_url, especialidad_id, carrera, nivel_academico)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING *`,
      [user.usuario_id, ...params],
    );

    return inserted.rows[0];
  }

  private async upsertDatosPrivadosAsesor(
    client: PoolClient,
    user: CurrentUser,
    payload: {
      nombresEncriptados: string;
      apellidosEncriptados: string;
      dniEncriptado: string;
      telefonoEncriptado: string | null;
    },
  ) {
    const existing = await client.query<{ id: string }>(
      `SELECT id
       FROM "AT".datos_privados_asesor
       WHERE asesor_id = $1
       LIMIT 1`,
      [user.usuario_id],
    );

    if (existing.rows[0]) {
      await client.query(
        `UPDATE "AT".datos_privados_asesor
         SET nombres_encriptados = $2,
             apellidos_encriptados = $3,
             dni_encriptado = $4,
             telefono_encriptado = $5,
             actualizado_en = now()
         WHERE id = $1`,
        [
          existing.rows[0].id,
          payload.nombresEncriptados,
          payload.apellidosEncriptados,
          payload.dniEncriptado,
          payload.telefonoEncriptado,
        ],
      );
      return;
    }

    await client.query(
      `INSERT INTO "AT".datos_privados_asesor
         (asesor_id, nombres_encriptados, apellidos_encriptados, dni_encriptado,
          telefono_encriptado)
       VALUES ($1, $2, $3, $4, $5)`,
      [
        user.usuario_id,
        payload.nombresEncriptados,
        payload.apellidosEncriptados,
        payload.dniEncriptado,
        payload.telefonoEncriptado,
      ],
    );
  }

  private hasStudentProfile(perfil: StudentProfileRow | undefined) {
    if (!perfil) {
      return false;
    }

    return Boolean(
      perfil.perfil_id ||
        perfil.nombres ||
        perfil.apellidos ||
        perfil.dni_encriptado,
    );
  }

  private hasAdvisorProfile(perfil: AdvisorProfileRow | undefined) {
    if (!perfil) {
      return false;
    }

    return Boolean(
      perfil.perfil_id ||
        perfil.nombre_mostrar ||
        perfil.slug ||
        perfil.dni_encriptado,
    );
  }

  private serializeStudentProfile(perfil: StudentProfileRow) {
    return {
      tiene_informacion: true,
      perfil_id: perfil.perfil_id,
      estudiante_id: perfil.estudiante_id,
      nombres: perfil.nombres ?? '',
      apellidos: perfil.apellidos ?? '',
      universidad_id: perfil.universidad_id,
      carrera: perfil.carrera ?? '',
      foto_url: perfil.foto_url ?? '',
      dni: this.cryptoService.decrypt(perfil.dni_encriptado) ?? '',
      telefono: this.cryptoService.decrypt(perfil.telefono_encriptado),
      creado_en: perfil.creado_en,
      actualizado_en: perfil.actualizado_en,
    };
  }

  private serializeAdvisorProfile(perfil: AdvisorProfileRow) {
    return {
      tiene_informacion: true,
      perfil_id: perfil.perfil_id,
      asesor_id: perfil.asesor_id,
      nombre_mostrar: perfil.nombre_mostrar ?? '',
      universidad_id: perfil.universidad_id,
      slug: perfil.slug ?? '',
      email_publico: perfil.email_publico ?? '',
      biografia: perfil.biografia ?? '',
      foto_url: perfil.foto_url ?? '',
      especialidad_id: perfil.especialidad_id,
      carrera: perfil.carrera ?? '',
      nivel_academico: perfil.nivel_academico ?? '',
      nombres: this.cryptoService.decrypt(perfil.nombres_encriptados) ?? '',
      apellidos: this.cryptoService.decrypt(perfil.apellidos_encriptados) ?? '',
      dni: this.cryptoService.decrypt(perfil.dni_encriptado) ?? '',
      telefono: this.cryptoService.decrypt(perfil.telefono_encriptado),
      creado_en: perfil.creado_en,
      actualizado_en: perfil.actualizado_en,
    };
  }

  private buildAdvisorDisplayName(dto: GuardarPerfilAsesorDto) {
    const fullName = `${dto.nombres} ${dto.apellidos}`.trim();
    return fullName || null;
  }

  private requireRole(user: CurrentUser, role: CurrentUser['rol']) {
    if (user.rol !== role) {
      throw new ForbiddenException(`Esta operación requiere rol ${role}`);
    }
  }

  private slugify(value: string): string {
    return value
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 150);
  }

  private async validateDto<T extends object>(
    dtoClass: new () => T,
    payload: Record<string, unknown>,
  ) {
    const dto = plainToInstance(dtoClass, payload);
    const errors = await validate(dto, {
      whitelist: true,
      forbidNonWhitelisted: true,
    });

    if (errors.length > 0) {
      throw new BadRequestException(this.flattenValidationErrors(errors));
    }

    return dto;
  }

  private flattenValidationErrors(
    errors: ValidationError[],
    prefix = '',
  ): string[] {
    return errors.flatMap((error) => {
      const property = prefix ? `${prefix}.${error.property}` : error.property;
      const messages = error.constraints
        ? Object.values(error.constraints).map((message) => `${property}: ${message}`)
        : [];
      const children = error.children?.length
        ? this.flattenValidationErrors(error.children, property)
        : [];

      return [...messages, ...children];
    });
  }
}
