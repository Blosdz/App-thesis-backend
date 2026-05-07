import { Injectable } from '@nestjs/common';
import { CurrentUser } from '../common/interfaces/current-user.interface';
import { DatabaseService } from '../database/database.service';
import { ComprarPlanDto } from './dto/comprar-plan.dto';

@Injectable()
export class PlanesService {
  constructor(private readonly databaseService: DatabaseService) {}

  async listar() {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_planes_disponibles()',
    );

    return { ok: true, data: result.rows };
  }

  async comprar(user: CurrentUser, dto: ComprarPlanDto) {
    const result = await this.databaseService.query(
      'SELECT * FROM "AT".fn_plan_comprar($1, $2)',
      [user.usuario_id, dto.planId],
    );

    return { ok: true, data: result.rows[0] };
  }
}
