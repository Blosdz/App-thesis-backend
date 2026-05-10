import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as crypto from 'crypto';

@Injectable()
export class CryptoService {
  private readonly algorithm = 'aes-256-gcm';
  private readonly key: Buffer;

  constructor(private readonly configService: ConfigService) {
    const secret = this.configService.get<string>('DATA_ENCRYPTION_KEY');

    if (!secret || Buffer.byteLength(secret, 'utf8') !== 32) {
      throw new Error(
        'DATA_ENCRYPTION_KEY debe tener exactamente 32 caracteres ASCII para AES-256-GCM',
      );
    }

    this.key = Buffer.from(secret, 'utf8');
  }

  encrypt(value: string | null | undefined): string | null {
    if (value === null || value === undefined || value.trim() === '') {
      return null;
    }

    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv(this.algorithm, this.key, iv);
    const encrypted = Buffer.concat([
      cipher.update(value, 'utf8'),
      cipher.final(),
    ]);
    const authTag = cipher.getAuthTag();

    return [
      iv.toString('base64'),
      authTag.toString('base64'),
      encrypted.toString('base64'),
    ].join(':');
  }

  decrypt(payload: string | null | undefined): string | null {
    if (!payload) {
      return null;
    }

    const parts = payload.split(':');

    if (parts.length !== 3) {
      throw new Error('Formato de dato encriptado inválido');
    }

    const [ivBase64, authTagBase64, encryptedBase64] = parts;
    const iv = Buffer.from(ivBase64, 'base64');
    const authTag = Buffer.from(authTagBase64, 'base64');
    const encrypted = Buffer.from(encryptedBase64, 'base64');

    const decipher = crypto.createDecipheriv(this.algorithm, this.key, iv);
    decipher.setAuthTag(authTag);

    const decrypted = Buffer.concat([
      decipher.update(encrypted),
      decipher.final(),
    ]);

    return decrypted.toString('utf8');
  }
}
