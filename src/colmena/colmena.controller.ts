import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { CurrentUserDecorator } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../common/guards/jwt-auth.guard';
import type { CurrentUser } from '../common/interfaces/current-user.interface';
import { ColmenaService } from './colmena.service';

/**
 * Endpoints autenticados del tenant COLMENA: traer un gráfico (base64) y
 * persistirlo asociado a la tesis para exportarlo luego en el documento Word.
 */
@UseGuards(JwtAuthGuard)
@Controller('colmena')
export class ColmenaController {
  constructor(private readonly colmenaService: ColmenaService) {}

  @Get('charts/:formId/:artifactId')
  getChart(
    @Param('formId') formId: string,
    @Param('artifactId') artifactId: string,
  ) {
    return this.colmenaService.getChartBase64(formId, artifactId);
  }

  @Get(':tesisId/charts')
  listThesisCharts(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
  ) {
    return this.colmenaService.listThesisCharts(tesisId, user);
  }

  @Post(':tesisId/charts/import')
  importChart(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @Body() body: { form_id: string; artifact_id: string; titulo?: string },
  ) {
    return this.colmenaService.importChartToThesis(
      tesisId,
      body.form_id,
      body.artifact_id,
      user,
      body.titulo,
    );
  }

  @Get(':tesisId/forms/:formId/baremos')
  listFormBaremos(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @Param('formId') formId: string,
  ) {
    return this.colmenaService.listFormBaremos(tesisId, formId, user);
  }

  @Get(':tesisId/baremos')
  listThesisBaremos(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
  ) {
    return this.colmenaService.listThesisBaremos(tesisId, user);
  }

  @Post(':tesisId/baremos/import')
  importBaremo(
    @CurrentUserDecorator() user: CurrentUser,
    @Param('tesisId') tesisId: string,
    @Body()
    body: { form_id: string; scoring_config_id: string; titulo?: string },
  ) {
    return this.colmenaService.importBaremoToThesis(
      tesisId,
      body.form_id,
      body.scoring_config_id,
      user,
      body.titulo,
    );
  }
}
