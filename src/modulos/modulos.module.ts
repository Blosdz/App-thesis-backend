import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { ModulosController } from './modulos.controller';
import { ModulosService } from './modulos.service';

@Module({
  imports: [DatabaseModule],
  controllers: [ModulosController],
  providers: [ModulosService],
})
export class ModulosModule {}
