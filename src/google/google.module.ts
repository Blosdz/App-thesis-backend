import { Module } from '@nestjs/common';
import { GoogleAuthService } from './google-auth.service';
import { GoogleCalendarService } from './google-calendar.service';
import { GoogleController } from './google.controller';
import { GoogleDriveService } from './google-drive.service';

@Module({
  controllers: [GoogleController],
  providers: [GoogleAuthService, GoogleDriveService, GoogleCalendarService],
  exports: [GoogleDriveService, GoogleCalendarService],
})
export class GoogleModule {}
