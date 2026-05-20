import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import type { PoolClient } from 'pg';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { NotificationsService } from '../notifications/notifications.service';
import { LocalStorageService } from '../storage/local-storage.service';
import { ActualizarCursoDto } from './dto/actualizar-curso.dto';
import { CrearCursoDto } from './dto/crear-curso.dto';
import { CrearMaterialCursoDto } from './dto/crear-material-curso.dto';

type Queryable = {
  query: (sql: string, params?: unknown[]) => Promise<{ rows: any[] }>;
};

@Injectable()
export class CursosService {
  constructor(
    private readonly databaseService: DatabaseService,
    private readonly notificationsService: NotificationsService,
    private readonly localStorageService: LocalStorageService,
  ) {}

  async misCursosAsesor(user: CurrentUser) {
    const result = await this.databaseService.query(
      `SELECT
         pc.*,
         COUNT(pm.id) FILTER (WHERE pm.activo = true) AS total_materiales,
         COUNT(ec.id) AS total_compras,
         COUNT(ec.id) FILTER (WHERE ec.estado = 'activo') AS compras_activas
       FROM "AT".profesor_cursos pc
       LEFT JOIN "AT".profesor_curso_materiales pm ON pm.curso_id = pc.id
       LEFT JOIN "AT".estudiante_cursos ec ON ec.curso_id = pc.id
       WHERE pc.asesor_id = $1
       GROUP BY pc.id
       ORDER BY pc.creado_en DESC`,
      [user.usuario_id],
    );

    return { ok: true, data: result.rows };
  }

  async crearCursoAsesor(user: CurrentUser, dto: CrearCursoDto) {
    const result = await this.databaseService.withTransaction(async (client) => {
      const cursoResult = await client.query(
        `INSERT INTO "AT".profesor_cursos
           (asesor_id, titulo, descripcion, precio, moneda, portada_drive_id,
            portada_url_drive, estado)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING *`,
        [
          user.usuario_id,
          dto.titulo,
          dto.descripcion ?? null,
          dto.precio,
          dto.moneda ?? 'PEN',
          dto.portadaDriveId ?? null,
          dto.portadaUrlDrive ?? null,
          dto.estado ?? 'borrador',
        ],
      );

      return cursoResult;
    });

    return {
      ok: true,
      message: 'Curso creado correctamente',
      data: result.rows[0],
    };
  }

  async actualizarCursoAsesor(
    user: CurrentUser,
    cursoId: string,
    dto: ActualizarCursoDto,
  ) {
    this.assertValidUuid(cursoId, 'ID de curso inválido');
    await this.assertCursoOwner(user, cursoId);

    const result = await this.databaseService.withTransaction(async (client) => {
      const cursoResult = await client.query(
        `UPDATE "AT".profesor_cursos
         SET titulo = COALESCE($2, titulo),
             descripcion = COALESCE($3, descripcion),
             precio = COALESCE($4, precio),
             moneda = COALESCE($5, moneda),
             portada_drive_id = COALESCE($6, portada_drive_id),
             portada_url_drive = COALESCE($7, portada_url_drive),
             estado = COALESCE($8, estado),
             activo = COALESCE($9, activo),
             actualizado_en = now()
         WHERE id = $1
         RETURNING *`,
        [
          cursoId,
          dto.titulo ?? null,
          dto.descripcion ?? null,
          dto.precio ?? null,
          dto.moneda ?? null,
          dto.portadaDriveId ?? null,
          dto.portadaUrlDrive ?? null,
          dto.estado ?? null,
          dto.activo ?? null,
        ],
      );

      return cursoResult;
    });

    return {
      ok: true,
      message: 'Curso actualizado correctamente',
      data: result.rows[0],
    };
  }

  async crearMaterialAsesor(
    user: CurrentUser,
    cursoId: string,
    dto: CrearMaterialCursoDto,
  ) {
    this.assertValidUuid(cursoId, 'ID de curso inválido');
    await this.assertCursoOwner(user, cursoId);

    const result = await this.databaseService.withTransaction(async (client) => {
      const materialResult = await client.query(
        `INSERT INTO "AT".profesor_curso_materiales
          (curso_id, titulo, descripcion, tipo, drive_file_id, drive_folder_id,
            url_drive, ruta_storage, url_storage, nombre_archivo, tipo_mime,
            tamano_bytes, url_externa, orden, es_vista_previa)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
         RETURNING *`,
        [
          cursoId,
          dto.titulo,
          dto.descripcion ?? null,
          dto.tipo ?? 'documento',
          dto.driveFileId ?? null,
          dto.driveFolderId ?? null,
          dto.urlDrive ?? null,
          dto.rutaStorage ?? null,
          dto.urlStorage ?? dto.urlDrive ?? null,
          dto.nombreArchivo ?? null,
          dto.tipoMime ?? null,
          dto.tamanoBytes ?? null,
          dto.urlExterna ?? null,
          dto.orden ?? 1,
          dto.esVistaPrevia ?? false,
        ],
      );

      return materialResult;
    });

    return {
      ok: true,
      message: 'Material agregado correctamente',
      data: result.rows[0],
    };
  }

  async subirMaterialesAsesor(
    user: CurrentUser,
    cursoId: string,
    files: Express.Multer.File[] | undefined,
    payload: {
      titulo?: string;
      descripcion?: string;
      tipo?: string;
      orden?: string | number;
      esVistaPrevia?: string | boolean;
    },
  ) {
    this.assertValidUuid(cursoId, 'ID de curso inválido');
    await this.assertCursoOwner(user, cursoId);

    const selectedFiles = Array.isArray(files)
      ? files.filter((file) => file?.buffer?.length)
      : [];

    if (!selectedFiles.length) {
      throw new BadRequestException('Selecciona al menos un archivo');
    }

    const baseOrder = Number(payload.orden || 1);
    const esVistaPrevia =
      payload.esVistaPrevia === true ||
      String(payload.esVistaPrevia).toLowerCase() === 'true';
    const tipo = this.resolveMaterialType(payload.tipo, selectedFiles[0]);

    const result = await this.databaseService.withTransaction(async (client) => {
      const insertedRows: any[] = [];

      for (const [index, file] of selectedFiles.entries()) {
        const savedFile = await this.localStorageService.saveFile(file, {
          directory: `cursos/${cursoId}/materiales`,
          fileNamePrefix: file.originalname,
        });
        const title =
          selectedFiles.length === 1
            ? payload.titulo || this.stripExtension(file.originalname)
            : `${payload.titulo || this.stripExtension(file.originalname)} ${index + 1}`;

        const inserted = await client.query(
          `INSERT INTO "AT".profesor_curso_materiales
             (curso_id, titulo, descripcion, tipo, drive_file_id, drive_folder_id,
              url_drive, ruta_storage, url_storage, nombre_archivo, tipo_mime,
              tamano_bytes, url_externa, orden, es_vista_previa)
           VALUES ($1, $2, $3, $4, null, null, $5, $6, $5, $7, $8, $9, null, $10, $11)
           RETURNING *`,
          [
            cursoId,
            title,
            payload.descripcion || null,
            this.resolveMaterialType(payload.tipo, file) || tipo,
            savedFile.publicUrl,
            savedFile.relativePath,
            file.originalname,
            savedFile.mimeType,
            savedFile.size,
            Math.max(1, baseOrder + index),
            esVistaPrevia,
          ],
        );

        insertedRows.push(inserted.rows[0]);
      }

      return insertedRows;
    });

    return {
      ok: true,
      message: 'Materiales subidos correctamente',
      data: result,
    };
  }

  async materialesCursoAsesor(user: CurrentUser, cursoId: string) {
    this.assertValidUuid(cursoId, 'ID de curso inválido');
    await this.assertCursoOwner(user, cursoId);

    const result = await this.databaseService.query(
      `SELECT *
       FROM "AT".profesor_curso_materiales
       WHERE curso_id = $1
       ORDER BY orden ASC, creado_en ASC`,
      [cursoId],
    );

    return { ok: true, data: result.rows };
  }

  async cursosDeAsesor(user: CurrentUser, asesorId: string) {
    this.assertValidUuid(asesorId, 'ID de asesor inválido');
    await this.assertRelacionActiva(user.usuario_id, asesorId);

    const result = await this.databaseService.query(
      `SELECT
         pc.*,
         ppa.nombre_mostrar AS asesor_nombre,
         ppa.foto_url AS asesor_foto_url,
         ppa.slug AS asesor_slug,
         COUNT(pm.id) FILTER (WHERE pm.activo = true) AS total_materiales,
         ec.id AS estudiante_curso_id,
         ec.estado AS estado_compra,
         ec.pago_id,
         p.estado AS estado_pago
       FROM "AT".profesor_cursos pc
       LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = pc.asesor_id
       LEFT JOIN "AT".profesor_curso_materiales pm ON pm.curso_id = pc.id
       LEFT JOIN "AT".estudiante_cursos ec
         ON ec.curso_id = pc.id
        AND ec.estudiante_id = $1
       LEFT JOIN "AT".pagos p ON p.id = ec.pago_id
       WHERE pc.asesor_id = $2
         AND pc.estado = 'publicado'
         AND pc.activo = true
       GROUP BY pc.id, ppa.nombre_mostrar, ppa.foto_url, ppa.slug, ec.id, p.estado
       ORDER BY pc.creado_en DESC`,
      [user.usuario_id, asesorId],
    );

    return { ok: true, data: result.rows };
  }

  async misCursosEstudiante(user: CurrentUser) {
    const result = await this.databaseService.query(
      `SELECT
         ec.*,
         pc.titulo,
         pc.descripcion,
         pc.precio,
         pc.moneda,
         pc.portada_url_drive,
         pc.asesor_id,
         ppa.nombre_mostrar AS asesor_nombre,
         ppa.foto_url AS asesor_foto_url,
         p.estado AS estado_pago,
         COUNT(pm.id) FILTER (WHERE pm.activo = true) AS total_materiales
       FROM "AT".estudiante_cursos ec
       JOIN "AT".profesor_cursos pc ON pc.id = ec.curso_id
       LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = pc.asesor_id
       LEFT JOIN "AT".pagos p ON p.id = ec.pago_id
       LEFT JOIN "AT".profesor_curso_materiales pm ON pm.curso_id = pc.id
       WHERE ec.estudiante_id = $1
         AND ec.activo = true
       GROUP BY ec.id, pc.id, ppa.nombre_mostrar, ppa.foto_url, p.estado
       ORDER BY ec.creado_en DESC`,
      [user.usuario_id],
    );

    return { ok: true, data: result.rows };
  }

  async detalleCursoEstudiante(user: CurrentUser, cursoId: string) {
    this.assertValidUuid(cursoId, 'ID de curso inválido');

    const cursoResult = await this.databaseService.query(
      `SELECT
         pc.*,
         ppa.nombre_mostrar AS asesor_nombre,
         ppa.foto_url AS asesor_foto_url,
         ec.id AS estudiante_curso_id,
         ec.estado AS estado_compra,
         ec.pago_id
       FROM "AT".profesor_cursos pc
       LEFT JOIN "AT".perfil_publico_asesor ppa ON ppa.asesor_id = pc.asesor_id
       LEFT JOIN "AT".estudiante_cursos ec
         ON ec.curso_id = pc.id
        AND ec.estudiante_id = $2
       WHERE pc.id = $1
         AND pc.activo = true
       LIMIT 1`,
      [cursoId, user.usuario_id],
    );

    const curso = cursoResult.rows[0];
    if (!curso) {
      throw new NotFoundException('Curso no encontrado');
    }

    await this.assertRelacionActiva(user.usuario_id, curso.asesor_id);

    const canAccessMaterials = curso.estado_compra === 'activo';
    const materialsResult = await this.databaseService.query(
      `SELECT *
       FROM "AT".profesor_curso_materiales
       WHERE curso_id = $1
         AND activo = true
         AND ($2::boolean = true OR es_vista_previa = true)
       ORDER BY orden ASC, creado_en ASC`,
      [cursoId, canAccessMaterials],
    );

    return {
      ok: true,
      data: {
        ...curso,
        materiales: materialsResult.rows,
      },
    };
  }

  async comprarCurso(user: CurrentUser, cursoId: string) {
    this.assertValidUuid(cursoId, 'ID de curso inválido');

    const result = await this.databaseService.withTransaction(async (client) => {
      const cursoResult = await client.query<{
        id: string;
        asesor_id: string;
        titulo: string;
        precio: string;
        moneda: string;
      }>(
        `SELECT id, asesor_id, titulo, precio, moneda
         FROM "AT".profesor_cursos
         WHERE id = $1
           AND estado = 'publicado'
           AND activo = true
         LIMIT 1
         FOR UPDATE`,
        [cursoId],
      );

      const curso = cursoResult.rows[0];
      if (!curso) {
        throw new NotFoundException('Curso no encontrado o no publicado');
      }

      await this.assertRelacionActiva(user.usuario_id, curso.asesor_id, client);

      const existingResult = await client.query(
        `SELECT ec.*, p.estado AS estado_pago
         FROM "AT".estudiante_cursos ec
         LEFT JOIN "AT".pagos p ON p.id = ec.pago_id
         WHERE ec.estudiante_id = $1
           AND ec.curso_id = $2
         LIMIT 1
         FOR UPDATE OF ec`,
        [user.usuario_id, cursoId],
      );

      const existing = existingResult.rows[0];
      if (existing?.estado === 'activo') {
        return { estudianteCurso: existing, pago: null, alreadyActive: true };
      }

      if (
        existing?.pago_id &&
        ['pendiente', 'voucher_subido'].includes(existing.estado_pago)
      ) {
        return { estudianteCurso: existing, pago: null, alreadyPending: true };
      }

      const pagoResult = await client.query(
        `INSERT INTO "AT".pagos
           (pagador_id, concepto, monto, estado, codigo_operacion, metadata, nota_verificacion)
         VALUES ($1, $2, $3, 'pendiente', $4, $5, $6)
         RETURNING *`,
        [
          user.usuario_id,
          `curso:${curso.titulo}`,
          curso.precio,
          this.buildPaymentCode(randomUUID()),
          {
            tipo: 'curso',
            curso_id: curso.id,
            asesor_id: curso.asesor_id,
            moneda: curso.moneda,
          },
          'Pago de curso creado automaticamente',
        ],
      );

      const estudianteCursoResult = existing
        ? await client.query(
            `UPDATE "AT".estudiante_cursos
             SET pago_id = $3,
                 estado = 'pendiente_pago',
                 precio_pagado = $4,
                 moneda = $5,
                 activo = true,
                 actualizado_en = now()
             WHERE estudiante_id = $1
               AND curso_id = $2
             RETURNING *`,
            [
              user.usuario_id,
              cursoId,
              pagoResult.rows[0].id,
              curso.precio,
              curso.moneda,
            ],
          )
        : await client.query(
            `INSERT INTO "AT".estudiante_cursos
               (estudiante_id, curso_id, pago_id, estado, precio_pagado, moneda)
             VALUES ($1, $2, $3, 'pendiente_pago', $4, $5)
             RETURNING *`,
            [
              user.usuario_id,
              cursoId,
              pagoResult.rows[0].id,
              curso.precio,
              curso.moneda,
            ],
          );

      await this.notificationsService.create(
        {
          userId: user.usuario_id,
          title: 'Pago de curso generado',
          description: `Se generó un pago pendiente para el curso ${curso.titulo}.`,
          type: 'curso_pago_generado',
          relatedId: pagoResult.rows[0].id,
          path: '/student/payments',
        },
        client,
      );

      await this.notifyAdmins(
        {
          title: 'Curso pendiente de validación',
          description: `Un estudiante inició la compra del curso ${curso.titulo}.`,
          type: 'curso_pago_pendiente',
          relatedId: pagoResult.rows[0].id,
          path: '/admin/payments',
        },
        client,
      );

      return {
        estudianteCurso: estudianteCursoResult.rows[0],
        pago: pagoResult.rows[0],
      };
    });

    if (result.alreadyActive) {
      return {
        ok: true,
        message: 'Ya tienes acceso activo a este curso',
        data: result.estudianteCurso,
      };
    }

    if (result.alreadyPending) {
      return {
        ok: true,
        message: 'Ya existe un pago pendiente para este curso',
        data: result.estudianteCurso,
      };
    }

    return {
      ok: true,
      message: 'Compra iniciada correctamente',
      data: result.estudianteCurso,
      pago: result.pago,
    };
  }

  async activarCompraPorPago(
    pagoId: string,
    queryable: Queryable = this.databaseService,
  ) {
    const compraResult = await queryable.query(
      `UPDATE "AT".estudiante_cursos ec
       SET estado = 'activo',
           comprado_en = COALESCE(comprado_en, now()),
           acceso_habilitado_en = COALESCE(acceso_habilitado_en, now()),
           actualizado_en = now()
       WHERE ec.pago_id = $1
         AND ec.estado <> 'activo'
       RETURNING ec.*`,
      [pagoId],
    );

    const compra = compraResult.rows[0];
    if (!compra) {
      return null;
    }

    const cursoResult = await queryable.query(
      `SELECT pc.titulo, pc.asesor_id
       FROM "AT".profesor_cursos pc
       WHERE pc.id = $1
       LIMIT 1`,
      [compra.curso_id],
    );
    const curso = cursoResult.rows[0];

    await this.notificationsService.create(
      {
        userId: compra.estudiante_id,
        title: 'Curso habilitado',
        description: `Tu compra${curso?.titulo ? ` de ${curso.titulo}` : ''} fue validada.`,
        type: 'curso_activado',
        relatedId: compra.curso_id,
        path: '/student/cursos',
      },
      queryable,
    );

    if (curso?.asesor_id) {
      await this.notificationsService.create(
        {
          userId: curso.asesor_id,
          title: 'Curso comprado',
          description: `Un estudiante ya tiene acceso al curso ${curso.titulo}.`,
          type: 'curso_vendido',
          relatedId: compra.curso_id,
          path: '/advisor/cursos',
        },
        queryable,
      );
    }

    return compra;
  }

  private async assertCursoOwner(user: CurrentUser, cursoId: string) {
    const result = await this.databaseService.query(
      `SELECT id
       FROM "AT".profesor_cursos
       WHERE id = $1
         AND asesor_id = $2
       LIMIT 1`,
      [cursoId, user.usuario_id],
    );

    if (!result.rows[0]) {
      throw new NotFoundException('Curso no encontrado');
    }
  }

  private async assertRelacionActiva(
    estudianteId: string,
    asesorId: string,
    queryable: Queryable = this.databaseService,
  ) {
    const result = await queryable.query(
      `SELECT id
       FROM "AT".relaciones_asesor_estudiante
       WHERE estudiante_id = $1
         AND asesor_id = $2
         AND estado = 'activo'
       LIMIT 1`,
      [estudianteId, asesorId],
    );

    if (!result.rows[0]) {
      throw new ForbiddenException(
        'Solo puedes ver cursos de asesores vinculados contigo',
      );
    }
  }

  private async notifyAdmins(
    input: {
      title: string;
      description: string;
      type: string;
      relatedId: string;
      path: string;
    },
    queryable: PoolClient,
  ) {
    const admins = await queryable.query<{ id: string }>(
      `SELECT id
       FROM "AT".usuarios
       WHERE rol = 'admin'`,
    );

    for (const admin of admins.rows) {
      await this.notificationsService.create(
        {
          userId: admin.id,
          ...input,
        },
        queryable,
      );
    }
  }

  private buildPaymentCode(seed: string) {
    return `PAY-${seed.replace(/-/g, '').slice(0, 12).toUpperCase()}`;
  }

  private resolveMaterialType(tipo: string | undefined, file: Express.Multer.File) {
    const allowedTypes = ['documento', 'video', 'link', 'plantilla', 'imagen', 'zip', 'otro'];
    if (tipo && allowedTypes.includes(tipo)) {
      return tipo;
    }

    const mime = file.mimetype || '';
    const extension = file.originalname.split('.').pop()?.toLowerCase();

    if (mime.startsWith('video/')) return 'video';
    if (mime.startsWith('image/')) return 'imagen';
    if (extension === 'zip') return 'zip';
    return 'documento';
  }

  private stripExtension(fileName: string) {
    return fileName.replace(/\.[^.]+$/, '');
  }

  private assertValidUuid(value: string, message: string) {
    const isUuid =
      typeof value === 'string' &&
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(
        value,
      );

    if (!isUuid) {
      throw new BadRequestException(message);
    }
  }
}
