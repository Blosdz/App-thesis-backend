import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { mkdir, writeFile } from 'fs/promises';
import { extname, join } from 'path';

type SaveLocalFileOptions = {
  directory: string;
  fileNamePrefix?: string;
};

export type SavedLocalFile = {
  relativePath: string;
  absolutePath: string;
  publicUrl: string;
  originalName: string;
  mimeType: string | null;
  size: number;
};

@Injectable()
export class LocalStorageService {
  private readonly rootPath: string;
  private readonly publicBaseUrl: string;

  constructor(private readonly configService: ConfigService) {
    this.rootPath =
      this.configService.get<string>('LOCAL_STORAGE_ROOT') ||
      join(process.cwd(), 'storage');
    const publicBackendUrl =
      this.configService.get<string>('BACKEND_PUBLIC_URL') ||
      `http://localhost:${this.configService.get<string>('PORT') || '3000'}`;
    this.publicBaseUrl =
      this.configService.get<string>('PUBLIC_STORAGE_BASE_URL') ||
      `${publicBackendUrl.replace(/\/$/, '')}/storage`;
  }

  async saveFile(
    file: Express.Multer.File,
    options: SaveLocalFileOptions,
  ): Promise<SavedLocalFile> {
    if (!file?.buffer?.length) {
      throw new BadRequestException('El archivo está vacío');
    }

    const directory = this.normalizePathSegment(options.directory, 'general');
    const targetDirectory = join(this.rootPath, directory);
    await mkdir(targetDirectory, { recursive: true });

    const extension = this.getSafeExtension(file.originalname);
    const prefix = this.normalizeName(options.fileNamePrefix || 'archivo');
    const fileName = `${prefix}-${Date.now()}-${Math.random()
      .toString(36)
      .slice(2, 10)}${extension}`;
    const relativePath = `${directory}/${fileName}`;
    const absolutePath = join(this.rootPath, relativePath);

    await writeFile(absolutePath, file.buffer);

    return {
      relativePath,
      absolutePath,
      publicUrl: `${this.publicBaseUrl.replace(/\/$/, '')}/${relativePath}`,
      originalName: file.originalname,
      mimeType: file.mimetype || null,
      size: file.size,
    };
  }

  private getSafeExtension(originalName: string) {
    const extension = extname(originalName || '').toLowerCase();
    return extension && /^[a-z0-9.]+$/.test(extension) ? extension : '.bin';
  }

  private normalizePathSegment(value: string, fallback: string) {
    return value
      .split('/')
      .map((part) => this.normalizeName(part, fallback))
      .filter(Boolean)
      .join('/');
  }

  private normalizeName(value: string, fallback = 'archivo') {
    const normalized = value
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .replace(/[^a-z0-9_-]+/g, '-')
      .replace(/^-+|-+$/g, '')
      .slice(0, 80);

    return normalized || fallback;
  }
}
