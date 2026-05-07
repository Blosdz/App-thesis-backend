import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { CreateDriveFolderDto } from './dto/create-drive-folder.dto';
import { CreateMeetDto } from './dto/create-meet.dto';
import { GoogleCalendarService } from './google-calendar.service';
import { GoogleDriveService } from './google-drive.service';

@Controller('google')
@UseGuards(JwtAuthGuard)
export class GoogleController {
  constructor(
    private readonly databaseService: DatabaseService,
    private readonly googleDriveService: GoogleDriveService,
    private readonly googleCalendarService: GoogleCalendarService,
  ) {}

  @Post('drive/folders/tesis/:tesisId')
  async createTesisFolder(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @Body() dto: CreateDriveFolderDto,
  ) {
    const folder = await this.googleDriveService.createFolder(
      dto.nombre ?? `tesis-${tesisId}`,
      dto.parentFolderId,
    );
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_tesis_guardar_carpeta_drive($1, $2, $3)',
      [user.usuario_id, tesisId, folder.id],
    );

    return { ok: true, data: { folder, tesis: result.rows[0] } };
  }

  @Post('meet')
  async createMeet(@Body() dto: CreateMeetDto) {
    const event = await this.googleCalendarService.createMeetEvent({
      summary: dto.summary,
      description: dto.description,
      start: dto.start,
      end: dto.end,
    });

    return { ok: true, data: event };
  }
}
