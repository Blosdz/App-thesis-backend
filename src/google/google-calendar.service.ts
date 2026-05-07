import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'crypto';
import { google } from 'googleapis';
import { GoogleAuthService } from './google-auth.service';

interface CreateMeetInput {
  summary: string;
  description?: string | null;
  start: string;
  end: string;
  attendees?: string[];
}

@Injectable()
export class GoogleCalendarService {
  constructor(
    private readonly googleAuthService: GoogleAuthService,
    private readonly configService: ConfigService,
  ) {}

  async createMeetEvent(input: CreateMeetInput) {
    const calendar = google.calendar({
      version: 'v3',
      auth: this.googleAuthService.getAuthClient(),
    });
    const calendarId = this.configService.get<string>(
      'GOOGLE_CALENDAR_ID',
      'primary',
    );

    const response = await calendar.events.insert({
      calendarId,
      conferenceDataVersion: 1,
      requestBody: {
        summary: input.summary,
        description: input.description ?? undefined,
        start: { dateTime: input.start },
        end: { dateTime: input.end },
        attendees: input.attendees?.map((email) => ({ email })),
        conferenceData: {
          createRequest: {
            requestId: randomUUID(),
            conferenceSolutionKey: { type: 'hangoutsMeet' },
          },
        },
      },
    });

    return response.data;
  }
}
