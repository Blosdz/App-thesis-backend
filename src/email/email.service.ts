import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Resend } from 'resend';

type SendEmailInput = {
  to: string | string[];
  subject: string;
  html: string;
  text?: string;
};

export type SendEmailResult =
  | { ok: true }
  | { ok: false; skipped?: true; status?: number; error?: string };

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private readonly resend: Resend | null;

  constructor(private readonly configService: ConfigService) {
    const apiKey = this.configService.get<string>('RESEND_API_KEY')?.trim();
    this.resend = apiKey ? new Resend(apiKey) : null;
  }

  isConfigured() {
    return Boolean(this.resend);
  }

  async sendEmail(input: SendEmailInput): Promise<SendEmailResult> {
    const from =
      this.configService.get<string>('EMAIL_FROM') ||
      'AppThesis <onboarding@resend.dev>';

    if (!this.resend) {
      this.logger.warn(
        `Email no enviado: falta RESEND_API_KEY. To=${JSON.stringify(
          input.to,
        )} Subject=${input.subject}`,
      );
      this.logger.debug(input.text || input.html);
      return { ok: false, skipped: true };
    }

    try {
      const { error } = await this.resend.emails.send({
        from,
        to: Array.isArray(input.to) ? input.to : [input.to],
        subject: input.subject,
        html: input.html,
        text: input.text,
      });

      if (error) {
        this.logger.error(`No se pudo enviar email con Resend: ${error.message}`);
        return { ok: false, error: error.name || 'resend_error' };
      }
    } catch (error) {
      this.logger.error('No se pudo conectar con Resend', error);
      return { ok: false, error: 'resend_unavailable' };
    }

    return { ok: true };
  }

  sendVerificationEmail(input: { to: string; verificationUrl: string }) {
    return this.sendEmail({
      to: input.to,
      subject: 'Verifica tu cuenta en AppThesis',
      text: `Verifica tu cuenta ingresando a: ${input.verificationUrl}`,
      html: `
        <p>Hola,</p>
        <p>Para activar tu cuenta en AppThesis, confirma tu correo electrónico.</p>
        <p><a href="${input.verificationUrl}">Verificar cuenta</a></p>
        <p>Si no creaste esta cuenta, puedes ignorar este mensaje.</p>
      `,
    });
  }

  sendPaymentSuccessEmail(input: {
    to: string | string[];
    concepto?: string | null;
    monto?: string | number | null;
  }) {
    const detail = input.concepto ? ` de ${input.concepto}` : '';
    const monto = input.monto ? ` por ${input.monto}` : '';

    return this.sendEmail({
      to: input.to,
      subject: 'Pago validado correctamente',
      text: `Tu pago${detail}${monto} fue validado correctamente.`,
      html: `
        <p>Hola,</p>
        <p>Tu pago${detail}${monto} fue validado correctamente.</p>
        <p>Ya puedes continuar usando los servicios asociados a este pago.</p>
      `,
    });
  }

  sendMeetingConfirmedEmail(input: {
    to: string | string[];
    title?: string;
    startAt?: string | Date | null;
    meetingUrl?: string | null;
  }) {
    const title = input.title || 'Reunión confirmada';
    const startAt = input.startAt
      ? new Date(input.startAt).toLocaleString('es-PE', {
          dateStyle: 'medium',
          timeStyle: 'short',
          timeZone: 'America/Lima',
        })
      : null;

    return this.sendEmail({
      to: input.to,
      subject: title,
      text: [
        'Tu reunión fue confirmada.',
        startAt ? `Fecha: ${startAt}` : null,
        input.meetingUrl ? `Enlace: ${input.meetingUrl}` : null,
      ]
        .filter(Boolean)
        .join('\n'),
      html: `
        <p>Hola,</p>
        <p>Tu reunión fue confirmada.</p>
        ${startAt ? `<p><strong>Fecha:</strong> ${startAt}</p>` : ''}
        ${
          input.meetingUrl
            ? `<p><a href="${input.meetingUrl}">Abrir enlace de reunión</a></p>`
            : ''
        }
      `,
    });
  }
}
