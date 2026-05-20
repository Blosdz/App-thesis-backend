import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'crypto';
import { google } from 'googleapis';
import { Readable } from 'stream';

type DriveFile = {
  id: string;
  name?: string;
  mimeType?: string;
  webViewLink?: string;
  webContentLink?: string;
  parents?: string[];
};

type DriveFolder = {
  id: string;
  name?: string;
  webViewLink?: string;
};

type DrivePermission = {
  id?: string | null;
  type?: string | null;
  role?: string | null;
  emailAddress?: string | null;
};

type MeetPayload = {
  summary: string;
  description?: string | null;
  location?: string | null;
  startAt: string;
  endAt: string;
  attendees?: Array<{ email: string; displayName?: string | null }>;
};

@Injectable()
export class GoogleService {
  constructor(private readonly configService: ConfigService) {}

  normalizeName(value: string | null | undefined, fallback = 'archivo') {
    const normalized = String(value || fallback)
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[^\w\s.-]/g, '')
      .trim()
      .replace(/\s+/g, '_')
      .slice(0, 120);

    return normalized || fallback;
  }

  getDriveRootFolderId(kind: 'documents' | 'vouchers' | 'drive' = 'documents') {
    const specific =
      kind === 'vouchers'
        ? this.configService.get<string>('GOOGLE_DRIVE_VOUCHERS_FOLDER_ID')
        : null;
    const fallback =
      this.configService.get<string>('GOOGLE_DRIVE_FOLDER_ID') ||
      this.configService.get<string>('GOOGLE_DRIVE_ROOT_FOLDER_ID');
    return specific || fallback || null;
  }

  private getOAuthClient(scope: 'drive' | 'meet' = 'drive') {
    const prefix = scope === 'meet' ? 'GOOGLE_MEET_OAUTH_' : 'GOOGLE_OAUTH_';
    const fallbackPrefix = 'GOOGLE_OAUTH_';
    const clientId =
      this.configService.get<string>(`${prefix}CLIENT_ID`) ||
      this.configService.get<string>(`${fallbackPrefix}CLIENT_ID`);
    const clientSecret =
      this.configService.get<string>(`${prefix}CLIENT_SECRET`) ||
      this.configService.get<string>(`${fallbackPrefix}CLIENT_SECRET`);
    const refreshToken =
      this.configService.get<string>(`${prefix}REFRESH_TOKEN`) ||
      this.configService.get<string>(`${fallbackPrefix}REFRESH_TOKEN`);

    if (!clientId || !clientSecret || !refreshToken) {
      throw new InternalServerErrorException(
        'Faltan credenciales OAuth de Google',
      );
    }

    const oauth2Client = new google.auth.OAuth2(clientId, clientSecret);
    oauth2Client.setCredentials({ refresh_token: refreshToken });
    return oauth2Client;
  }

  private getDriveClient() {
    return google.drive({
      version: 'v3',
      auth: this.getOAuthClient('drive'),
    });
  }

  private escapeDriveQueryValue(value: string) {
    return value.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
  }

  async getAccessToken(scope: 'drive' | 'meet' = 'drive') {
    try {
      const tokenResponse = await this.getOAuthClient(scope).getAccessToken();
      const accessToken = tokenResponse.token;

      if (!accessToken) {
        throw new Error('Google no devolvió access_token');
      }

      return accessToken;
    } catch (error) {
      const googleError =
        (error as { response?: { data?: unknown }; message?: string })?.response
          ?.data ||
        (error as { message?: string })?.message ||
        'Error desconocido';

      throw new InternalServerErrorException(
        `Error obteniendo access token de Google: ${JSON.stringify(
          googleError,
        )}`,
      );
    }
  }

  async getDriveUser() {
    try {
      const drive = this.getDriveClient();
      const result = await drive.about.get({ fields: 'user' });
      return result.data.user;
    } catch (error) {
      throw new InternalServerErrorException(
        `Error consultando usuario de Drive: ${JSON.stringify(
          (error as { response?: { data?: unknown }; message?: string })
            ?.response?.data ||
            (error as { message?: string })?.message ||
            error,
        )}`,
      );
    }
  }

  async createDriveFolder({
    folderName,
    parentFolderId,
  }: {
    folderName: string;
    parentFolderId: string;
  }): Promise<DriveFolder> {
    try {
      const drive = this.getDriveClient();
      const created = await drive.files.create({
        requestBody: {
          name: folderName,
          mimeType: 'application/vnd.google-apps.folder',
          parents: [parentFolderId],
        },
        fields: 'id,name,webViewLink',
      });

      if (!created.data.id) {
        throw new Error('Google Drive no devolvió ID de carpeta');
      }

      return {
        id: created.data.id,
        name: created.data.name ?? undefined,
        webViewLink: created.data.webViewLink ?? undefined,
      };
    } catch (error) {
      throw new InternalServerErrorException(
        `Error creando carpeta Drive: ${JSON.stringify(
          (error as { response?: { data?: unknown }; message?: string })
            ?.response?.data ||
            (error as { message?: string })?.message ||
            error,
        )}`,
      );
    }
  }

  async findDriveFolder({
    folderName,
    parentFolderId,
  }: {
    folderName: string;
    parentFolderId: string;
  }): Promise<DriveFolder | null> {
    const query =
      `'${this.escapeDriveQueryValue(parentFolderId)}' in parents and ` +
      `mimeType = 'application/vnd.google-apps.folder' and trashed = false and ` +
      `name = '${this.escapeDriveQueryValue(folderName)}'`;

    try {
      const drive = this.getDriveClient();
      const existing = await drive.files.list({
        q: query,
        fields: 'files(id,name,webViewLink)',
        pageSize: 1,
        spaces: 'drive',
      });
      const folder = existing.data.files?.[0];

      if (!folder?.id) {
        return null;
      }

      return {
        id: folder.id,
        name: folder.name ?? undefined,
        webViewLink: folder.webViewLink ?? undefined,
      };
    } catch (error) {
      throw new InternalServerErrorException(
        `Error buscando carpeta Drive: ${JSON.stringify(
          (error as { response?: { data?: unknown }; message?: string })
            ?.response?.data ||
            (error as { message?: string })?.message ||
            error,
        )}`,
      );
    }
  }

  async getOrCreateDriveFolder(params: {
    folderName: string;
    parentFolderId: string;
  }): Promise<DriveFolder> {
    const existing = await this.findDriveFolder(params);
    if (existing) return existing;
    return this.createDriveFolder(params);
  }

  async uploadFileToDrive({
    file,
    folderId,
    fileName,
  }: {
    file: Express.Multer.File;
    folderId: string;
    fileName: string;
  }): Promise<DriveFile> {
    try {
      const drive = this.getDriveClient();
      const created = await drive.files.create({
        requestBody: {
          name: fileName,
          parents: [folderId],
        },
        media: {
          mimeType: file.mimetype || 'application/octet-stream',
          body: Readable.from(file.buffer),
        },
        fields: 'id,name,mimeType,webViewLink,webContentLink,parents',
      });

      if (!created.data.id) {
        throw new Error('Google Drive no devolvió ID del archivo');
      }

      return {
        id: created.data.id,
        name: created.data.name ?? undefined,
        mimeType: created.data.mimeType ?? undefined,
        webViewLink: created.data.webViewLink ?? undefined,
        webContentLink: created.data.webContentLink ?? undefined,
        parents: created.data.parents ?? undefined,
      };
    } catch (error) {
      throw new InternalServerErrorException(
        `Error subiendo archivo a Google Drive: ${JSON.stringify(
          (error as { response?: { data?: unknown }; message?: string })
            ?.response?.data ||
            (error as { message?: string })?.message ||
            error,
        )}`,
      );
    }
  }

  async restrictDriveItemToEmails({
    fileId,
    readerEmails,
    writerEmails = [],
  }: {
    fileId: string;
    readerEmails: string[];
    writerEmails?: string[];
  }) {
    if (!fileId) return null;

    const readers = this.normalizeEmailList(readerEmails);
    const writers = this.normalizeEmailList(writerEmails);
    const allowedEmails = new Set([...readers, ...writers]);

    try {
      const drive = this.getDriveClient();
      const permissions = await drive.permissions.list({
        fileId,
        fields: 'permissions(id,type,role,emailAddress)',
        supportsAllDrives: true,
      });

      const currentPermissions =
        (permissions.data.permissions || []) as DrivePermission[];
      const retainedPermissions: DrivePermission[] = [];

      for (const permission of currentPermissions) {
        if (!permission.id || permission.role === 'owner') {
          retainedPermissions.push(permission);
          continue;
        }

        const permissionEmail = permission.emailAddress?.toLowerCase();
        const shouldRemove =
          permission.type === 'anyone' ||
          permission.type === 'domain' ||
          (permission.type === 'user' &&
            permissionEmail &&
            !allowedEmails.has(permissionEmail));

        if (!shouldRemove) {
          retainedPermissions.push(permission);
          continue;
        }

        await drive.permissions.delete({
          fileId,
          permissionId: permission.id,
          supportsAllDrives: true,
        });
      }

      for (const email of writers) {
        await this.ensureDriveUserPermission(
          fileId,
          email,
          'writer',
          retainedPermissions,
        );
      }

      for (const email of readers) {
        if (writers.includes(email)) continue;
        await this.ensureDriveUserPermission(
          fileId,
          email,
          'reader',
          retainedPermissions,
        );
      }

      return { ok: true, fileId, readers, writers };
    } catch (error) {
      throw new InternalServerErrorException(
        `Error configurando permisos Drive: ${JSON.stringify(
          (error as { response?: { data?: unknown }; message?: string })
            ?.response?.data ||
            (error as { message?: string })?.message ||
            error,
        )}`,
      );
    }
  }

  private async ensureDriveUserPermission(
    fileId: string,
    emailAddress: string,
    role: 'reader' | 'writer',
    permissions: DrivePermission[],
  ) {
    const drive = this.getDriveClient();
    const existingPermission = permissions.find(
      (permission) =>
        permission.type === 'user' &&
        permission.emailAddress?.toLowerCase() === emailAddress,
    );

    if (existingPermission?.id) {
      if (
        existingPermission.role === role ||
        existingPermission.role === 'owner' ||
        (existingPermission.role === 'writer' && role === 'reader')
      ) {
        return;
      }

      await drive.permissions.update({
        fileId,
        permissionId: existingPermission.id,
        requestBody: {
          role,
        },
        fields: 'id',
        supportsAllDrives: true,
      });
      return;
    }

    await drive.permissions.create({
      fileId,
      requestBody: {
        type: 'user',
        role,
        emailAddress,
      },
      fields: 'id',
      sendNotificationEmail: false,
      supportsAllDrives: true,
    });
  }

  private normalizeEmailList(emails: string[]) {
    return [
      ...new Set(
        emails
          .map((email) => String(email || '').trim().toLowerCase())
          .filter(Boolean),
      ),
    ];
  }

  async createMeetEvent(payload: MeetPayload) {
    const accessToken = await this.getAccessToken('meet');
    const calendarId =
      this.configService.get<string>('GOOGLE_CALENDAR_ID') || 'primary';
    const attendees = (payload.attendees || [])
      .filter((attendee) => attendee.email)
      .filter(
        (attendee, index, collection) =>
          collection.findIndex((item) => item.email === attendee.email) ===
          index,
      );

    const eventPayload = {
      summary: payload.summary,
      description: payload.description || undefined,
      location: payload.location || undefined,
      start: { dateTime: payload.startAt },
      end: { dateTime: payload.endAt },
      attendees,
      guestsCanSeeOtherGuests: true,
      conferenceData: {
        createRequest: {
          requestId: randomUUID(),
          conferenceSolutionKey: { type: 'hangoutsMeet' },
        },
      },
    };

    let lastError: unknown = null;

    const response = await fetch(
      `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(
        calendarId,
      )}/events?conferenceDataVersion=1&sendUpdates=${
        attendees.length > 0 ? 'all' : 'none'
      }`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(eventPayload),
      },
    );
    const data = await response.json();

    if (response.ok) {
      return {
        eventData: data as Record<string, unknown>,
        calendarIdUsed: calendarId,
        meetUrl: this.extractMeetUrl(data as Record<string, unknown>),
        meetCode: this.extractMeetCode(data as Record<string, unknown>),
      };
    }

    lastError = data;

    throw new InternalServerErrorException(
      `Error creando Google Meet: ${JSON.stringify(lastError)}`,
    );
  }

  async downloadFileFromDrive(fileId: string): Promise<Readable> {
    try {
      const drive = this.getDriveClient();
      const response = await drive.files.get(
        { fileId, alt: 'media' },
        { responseType: 'stream' },
      );
      return response.data as Readable;
    } catch (error) {
      const googleError =
        (error as { response?: { data?: unknown }; message?: string })?.response
          ?.data ||
        (error as { message?: string })?.message ||
        'Error desconocido';

      throw new InternalServerErrorException(
        `Error descargando archivo de Drive: ${JSON.stringify(googleError)}`,
      );
    }
  }

  private extractMeetUrl(eventData: Record<string, unknown>) {
    const conferenceData = eventData.conferenceData as
      | {
          entryPoints?: Array<{ entryPointType?: string; uri?: string }>;
        }
      | undefined;

    return (
      (eventData.hangoutLink as string | undefined) ||
      conferenceData?.entryPoints?.find(
        (item) => item.entryPointType === 'video' && item.uri,
      )?.uri ||
      null
    );
  }

  private extractMeetCode(eventData: Record<string, unknown>) {
    return (
      (eventData.conferenceData as { conferenceId?: string } | undefined)
        ?.conferenceId || null
    );
  }
}
