import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'crypto';

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
  name: string;
};

type MeetPayload = {
  summary: string;
  description?: string | null;
  location?: string | null;
  startAt: string;
  endAt: string;
  attendees?: Array<{ email: string; displayName?: string | null }>;
  calendarId?: string | null;
};

@Injectable()
export class GoogleService {
  constructor(private readonly configService: ConfigService) {}

  normalizeName(value: string, fallback = 'archivo') {
    const normalized = value
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[^\w\s.-]/g, '')
      .trim()
      .replace(/\s+/g, '_')
      .slice(0, 120);

    return normalized || fallback;
  }

  getDriveRootFolderId(kind: 'documents' | 'vouchers' = 'documents') {
    const specific =
      kind === 'vouchers'
        ? this.configService.get<string>('GOOGLE_DRIVE_VOUCHERS_FOLDER_ID')
        : null;
    const fallback =
      this.configService.get<string>('GOOGLE_DRIVE_FOLDER_ID') ||
      this.configService.get<string>('GOOGLE_DRIVE_ROOT_FOLDER_ID');
    return specific || fallback || null;
  }

  private escapeDriveQueryValue(value: string) {
    return value.replace(/\\/g, '\\\\').replace(/'/g, "\\'");
  }

  async getAccessToken(scope: 'drive' | 'meet' = 'drive') {
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

    const response = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        refresh_token: refreshToken,
        grant_type: 'refresh_token',
      }),
    });

    const data = (await response.json()) as { access_token?: string };

    if (!response.ok || !data.access_token) {
      throw new InternalServerErrorException(
        `Error obteniendo access token de Google: ${JSON.stringify(data)}`,
      );
    }

    return data.access_token;
  }

  async getDriveUser(accessToken: string) {
    const response = await fetch(
      'https://www.googleapis.com/drive/v3/about?fields=user',
      { headers: { Authorization: `Bearer ${accessToken}` } },
    );
    const data = await response.json();

    if (!response.ok) {
      throw new InternalServerErrorException(
        `Error consultando usuario de Drive: ${JSON.stringify(data)}`,
      );
    }

    return data;
  }

  async createDriveFolder({
    folderName,
    parentFolderId,
    accessToken,
  }: {
    folderName: string;
    parentFolderId: string;
    accessToken: string;
  }): Promise<DriveFolder> {
    const response = await fetch('https://www.googleapis.com/drive/v3/files', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        name: folderName,
        mimeType: 'application/vnd.google-apps.folder',
        parents: [parentFolderId],
      }),
    });
    const data = (await response.json()) as DriveFolder;

    if (!response.ok) {
      throw new InternalServerErrorException(
        `Error creando carpeta Drive: ${JSON.stringify(data)}`,
      );
    }

    return data;
  }

  async findDriveFolder({
    folderName,
    parentFolderId,
    accessToken,
  }: {
    folderName: string;
    parentFolderId: string;
    accessToken: string;
  }): Promise<DriveFolder | null> {
    const query =
      `'${this.escapeDriveQueryValue(parentFolderId)}' in parents and ` +
      `mimeType = 'application/vnd.google-apps.folder' and trashed = false and ` +
      `name = '${this.escapeDriveQueryValue(folderName)}'`;

    const response = await fetch(
      `https://www.googleapis.com/drive/v3/files?q=${encodeURIComponent(query)}&fields=files(id,name)&pageSize=1`,
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      },
    );

    const data = (await response.json()) as { files?: DriveFolder[] };

    if (!response.ok) {
      throw new InternalServerErrorException(
        `Error buscando carpeta Drive: ${JSON.stringify(data)}`,
      );
    }

    return data.files?.[0] ?? null;
  }

  async getOrCreateDriveFolder(params: {
    folderName: string;
    parentFolderId: string;
    accessToken: string;
  }): Promise<DriveFolder> {
    const existing = await this.findDriveFolder(params);
    if (existing) return existing;
    return this.createDriveFolder(params);
  }

  async uploadFileToDrive({
    file,
    folderId,
    accessToken,
    fileName,
  }: {
    file: Express.Multer.File;
    folderId: string;
    accessToken: string;
    fileName: string;
  }): Promise<DriveFile> {
    const boundary = `foo_bar_baz_${randomUUID()}`;
    const delimiter = `\r\n--${boundary}\r\n`;
    const closeDelimiter = `\r\n--${boundary}--`;
    const preamble =
      delimiter +
      'Content-Type: application/json; charset=UTF-8\r\n\r\n' +
      JSON.stringify({ name: fileName, parents: [folderId] }) +
      delimiter +
      `Content-Type: ${file.mimetype || 'application/octet-stream'}\r\n\r\n`;

    const body = Buffer.concat([
      Buffer.from(preamble),
      file.buffer,
      Buffer.from(closeDelimiter),
    ]);

    const response = await fetch(
      'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,mimeType,webViewLink,webContentLink,parents',
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': `multipart/related; boundary=${boundary}`,
        },
        body,
      },
    );

    const data = (await response.json()) as DriveFile;

    if (!response.ok) {
      throw new InternalServerErrorException(
        `Error subiendo archivo a Google Drive: ${JSON.stringify(data)}`,
      );
    }

    return data;
  }

  async createMeetEvent(payload: MeetPayload) {
    const accessToken = await this.getAccessToken('meet');
    const defaultCalendarId =
      this.configService.get<string>('GOOGLE_CALENDAR_ID') || 'primary';
    const calendarIds =
      payload.calendarId && payload.calendarId !== defaultCalendarId
        ? [payload.calendarId, defaultCalendarId]
        : [defaultCalendarId];
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

    for (const calendarId of calendarIds) {
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
    }

    throw new InternalServerErrorException(
      `Error creando Google Meet: ${JSON.stringify(lastError)}`,
    );
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
