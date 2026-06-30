import { Body, Controller, Get, Param, Post } from '@nestjs/common';
import { ColmenaService } from './colmena.service';

/**
 * Acceso público (sin auth) a los formularios de COLMENA por código, proxeado
 * a través de AppThesis bajo el slug del tenant. El respondiente es anónimo.
 */
@Controller('colmena/public')
export class ColmenaPublicController {
  constructor(private readonly colmenaService: ColmenaService) {}

  @Get('forms/:code')
  getPublicForm(@Param('code') code: string) {
    return this.colmenaService.getPublicForm(code);
  }

  @Post('forms/:code/responses')
  submitPublicResponse(
    @Param('code') code: string,
    @Body() body: Record<string, unknown>,
  ) {
    return this.colmenaService.submitPublicResponse(code, body);
  }
}
