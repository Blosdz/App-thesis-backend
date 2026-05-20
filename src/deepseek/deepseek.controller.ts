import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { DocumentosService } from '../documentos/documentos.service';
import { DeepseekService, ChatMessage } from './deepseek.service';

@UseGuards(JwtAuthGuard)
@Controller('documentos/tesis/:tesisId/chat')
export class DeepseekController {
  constructor(
    private readonly deepseekService: DeepseekService,
    private readonly documentosService: DocumentosService,
  ) {}

  @Post()
  async sendMessage(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @Body()
    dto: {
      message: string;
      documentId?: string;
      conversationHistory?: ChatMessage[];
    },
  ) {
    // Verify user has access to this thesis
    await (this.documentosService as any).obtenerTesisAutorizada(user, tesisId);

    // Get conversation history if not provided
    let history = dto.conversationHistory || [];
    if (history.length === 0) {
      history = await this.deepseekService.getConversationHistory(
        tesisId,
        user.usuario_id,
        5,
      );
    }

    // Send message to Deepseek
    const response = await this.deepseekService.chat(
      tesisId,
      user.usuario_id,
      dto.documentId || null,
      dto.message,
      history,
    );

    return {
      ok: true,
      data: response,
    };
  }

  @Get('history')
  async getHistory(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
  ) {
    // Verify user has access to this thesis
    await (this.documentosService as any).obtenerTesisAutorizada(user, tesisId);

    const history = await this.deepseekService.getConversationHistory(
      tesisId,
      user.usuario_id,
      20,
    );

    return {
      ok: true,
      data: history,
    };
  }

  @Get('status')
  getStatus() {
    return {
      ok: true,
      configured: this.deepseekService.isConfigured(),
      message: this.deepseekService.isConfigured()
        ? 'Deepseek AI is ready'
        : 'Deepseek API key not configured',
    };
  }
}
