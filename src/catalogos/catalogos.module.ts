import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { CatalogosController } from './catalogos.controller';
import { CatalogosService } from './catalogos.service';

@Module({
  imports: [DatabaseModule],
  controllers: [CatalogosController],
  providers: [CatalogosService],
})
export class CatalogosModule {}
