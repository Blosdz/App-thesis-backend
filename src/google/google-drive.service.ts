import { Injectable } from '@nestjs/common';
import { Readable } from 'stream';
import { google } from 'googleapis';
import { ConfigService } from '@nestjs/config';
import { GoogleAuthService } from './google-auth.service';

@Injectable()
export class GoogleDriveService {
  constructor(
    private readonly googleAuthService: GoogleAuthService,
    private readonly configService: ConfigService,
  ) {}

  async uploadFile(file: Express.Multer.File, folderId?: string | null) {
    const drive = google.drive({
      version: 'v3',
      auth: this.googleAuthService.getAuthClient(),
    });

    const response = await drive.files.create({
      requestBody: {
        name: file.originalname,
        parents: [
          folderId ??
            this.configService.get<string>('GOOGLE_DRIVE_ROOT_FOLDER_ID'),
        ].filter(Boolean) as string[],
      },
      media: {
        mimeType: file.mimetype,
        body: Readable.from(file.buffer),
      },
      fields: 'id, webViewLink, name, mimeType, size',
    });

    return response.data;
  }

  async createFolder(name: string, parentFolderId?: string | null) {
    const drive = google.drive({
      version: 'v3',
      auth: this.googleAuthService.getAuthClient(),
    });

    const response = await drive.files.create({
      requestBody: {
        name,
        mimeType: 'application/vnd.google-apps.folder',
        parents: [
          parentFolderId ??
            this.configService.get<string>('GOOGLE_DRIVE_ROOT_FOLDER_ID'),
        ].filter(Boolean) as string[],
      },
      fields: 'id, webViewLink, name',
    });

    return response.data;
  }
}
