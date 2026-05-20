import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DatabaseService } from '../database/database.service';

export interface ChatMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

export interface ChatResponse {
  id: string;
  message: string;
  suggestions?: string[];
  canEdit: boolean;
  editWarning?: string;
}

@Injectable()
export class DeepseekService {
  private apiKey: string;
  private apiBaseUrl = 'https://api.deepseek.com/v1';
  private model: string;
  private temperature: number;
  private maxTokens: number;

  constructor(
    private readonly configService: ConfigService,
    private readonly databaseService: DatabaseService,
  ) {
    this.apiKey = this.configService.get<string>('DEEPSEEK_API_KEY') || '';
    this.model =
      this.configService.get<string>('DEEPSEEK_MODEL') || 'deepseek-chat';
    const temperature = Number(
      this.configService.get<string>('DEEPSEEK_TEMPERATURE') ?? 0.7,
    );
    const maxTokens = Number(
      this.configService.get<string>('DEEPSEEK_MAX_TOKENS') ?? 2000,
    );
    this.temperature = Number.isFinite(temperature) ? temperature : 0.7;
    this.maxTokens = Number.isFinite(maxTokens) ? maxTokens : 2000;
  }

  /**
   * Send a message to Deepseek and get a response
   * Contextualizes the message with document content
   */
  async chat(
    tesisId: string,
    usuarioId: string,
    documentId: string | null,
    userMessage: string,
    conversationHistory: ChatMessage[] = [],
  ): Promise<ChatResponse> {
    if (!this.apiKey) {
      throw new InternalServerErrorException('Deepseek API key not configured');
    }

    try {
      // Get document context if provided
      const documentContext = documentId
        ? await this.getDocumentContext(documentId)
        : null;

      // Build system prompt with context
      const systemPrompt = this.buildSystemPrompt(documentContext);

      // Prepare messages for API
      const messages: ChatMessage[] = [
        { role: 'system', content: systemPrompt },
        ...conversationHistory,
        { role: 'user', content: userMessage },
      ];

      // Call Deepseek API
      const response = await fetch(`${this.apiBaseUrl}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify({
          model: this.model,
          messages,
          temperature: this.temperature,
          max_tokens: this.maxTokens,
        }),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(
          `Deepseek API error: ${error.error?.message || 'Unknown error'}`,
        );
      }

      const data = await response.json();
      const assistantMessage =
        data.choices?.[0]?.message?.content || 'No response';

      // Store conversation in database
      await this.storeConversation(
        tesisId,
        usuarioId,
        documentId,
        userMessage,
        assistantMessage,
      );

      // Extract suggestions if the response contains them
      const suggestions = this.extractSuggestions(assistantMessage);

      return {
        id: Date.now().toString(),
        message: assistantMessage,
        suggestions,
        canEdit: conversationHistory.some((msg) =>
          msg.content.toLowerCase().includes('edita'),
        ),
        editWarning:
          suggestions.length > 0
            ? 'Revisa las sugerencias antes de aplicar cambios'
            : undefined,
      };
    } catch (error) {
      console.error('Error in Deepseek chat:', error);
      throw new InternalServerErrorException(
        `Error communicating with Deepseek: ${(error as Error).message}`,
      );
    }
  }

  /**
   * Get document content from database and format for context
   */
  private async getDocumentContext(documentId: string): Promise<string> {
    try {
      const result = await this.databaseService.query(
        `SELECT 
           dt.nombre,
           dt.tipo_documento,
           dt.url_archivo_drive,
           dt.documento_drive_id,
           COALESCE(dt.comentario_revision, '') as context_note
         FROM "AT".documentos_tesis dt
         WHERE dt.id = $1
         LIMIT 1`,
        [documentId],
      );

      if (!result.rows[0]) {
        return '';
      }

      const doc = result.rows[0];
      return `
Document context:
- Name: ${doc.nombre}
- Type: ${doc.tipo_documento || 'thesis document'}
- Last revision note: ${doc.context_note || 'None'}
- Document ID: ${doc.documento_drive_id}
      `.trim();
    } catch (error) {
      console.error('Error getting document context:', error);
      return '';
    }
  }

  /**
   * Build the system prompt that instructs the AI
   */
  private buildSystemPrompt(documentContext: string | null): string {
    const basePrompt = `You are an academic AI assistant specialized in thesis writing and research. 
Your role is to:
1. Help students improve their thesis quality
2. Identify gaps and suggest improvements
3. Provide structural feedback
4. Help with citations and academic rigor
5. Suggest edits to the document

When the user asks you to edit or modify the document, you should:
- Suggest specific changes with context
- Explain why changes would improve the document
- Be respectful and encouraging
- Maintain the student's original voice and intent

You communicate in Spanish when the document is in Spanish.`;

    if (documentContext) {
      return `${basePrompt}\n\nCurrent document context:\n${documentContext}`;
    }

    return basePrompt;
  }

  /**
   * Extract action suggestions from the AI response
   */
  private extractSuggestions(message: string): string[] {
    const suggestions: string[] = [];
    const lines = message.split('\n');

    lines.forEach((line) => {
      if (
        line.includes('Sugerencia:') ||
        line.includes('Edit:') ||
        line.includes('Change:')
      ) {
        suggestions.push(line.trim());
      }
    });

    return suggestions.slice(0, 3); // Return max 3 suggestions
  }

  /**
   * Store conversation history in database
   */
  private async storeConversation(
    tesisId: string,
    usuarioId: string,
    documentId: string | null,
    userMessage: string,
    assistantMessage: string,
  ): Promise<void> {
    try {
      // Check if conversation table exists, if not create it
      await this.databaseService.query(
        `INSERT INTO "AT".ai_conversations
           (tesis_id, usuario_id, documento_tesis_id, user_message, assistant_message, created_at)
         VALUES ($1, $2, $3, $4, $5, now())
         ON CONFLICT DO NOTHING`,
        [tesisId, usuarioId, documentId, userMessage, assistantMessage],
      );
    } catch (error) {
      // If table doesn't exist, it will be created by migration
      console.warn('Could not store conversation:', error);
    }
  }

  /**
   * Get conversation history for a thesis
   */
  async getConversationHistory(
    tesisId: string,
    usuarioId: string,
    limit: number = 10,
  ): Promise<ChatMessage[]> {
    try {
      const result = await this.databaseService.query(
        `SELECT user_message, assistant_message, created_at
         FROM "AT".ai_conversations
         WHERE tesis_id = $1
           AND usuario_id = $2
         ORDER BY created_at DESC
         LIMIT $3`,
        [tesisId, usuarioId, limit],
      );

      const messages: ChatMessage[] = [];

      // Reverse to get chronological order
      result.rows.reverse().forEach((row) => {
        messages.push({
          role: 'user',
          content: row.user_message,
        });
        messages.push({
          role: 'assistant',
          content: row.assistant_message,
        });
      });

      return messages;
    } catch (error) {
      console.warn('Could not retrieve conversation history:', error);
      return [];
    }
  }

  /**
   * Validate if Deepseek API is configured
   */
  isConfigured(): boolean {
    return Boolean(this.apiKey);
  }
}
