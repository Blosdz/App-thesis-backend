import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { PagosModule } from '../pagos/pagos.module';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';

@Module({
  imports: [DatabaseModule, PagosModule],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
