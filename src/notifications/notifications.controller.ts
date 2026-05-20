import { Controller, Get, Param, Patch, UseGuards } from '@nestjs/common';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { NotificationsService } from './notifications.service';

@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Get()
  list(@CurrentUserDecorator() user: CurrentUser) {
    return this.notificationsService.listForUser(user);
  }

  @Patch(':notificationId/read')
  markRead(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('notificationId') notificationId: string,
  ) {
    return this.notificationsService.markRead(user, notificationId);
  }

  @Patch('read-all')
  markAllRead(@CurrentUserDecorator() user: CurrentUser) {
    return this.notificationsService.markAllRead(user);
  }
}
