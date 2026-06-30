import { Module } from '@nestjs/common';
import { DatabaseModule } from '../database/database.module';
import { ColmenaController } from './colmena.controller';
import { ColmenaPublicController } from './colmena-public.controller';
import { ColmenaService } from './colmena.service';

@Module({
  imports: [DatabaseModule],
  controllers: [ColmenaController, ColmenaPublicController],
  providers: [ColmenaService],
  exports: [ColmenaService],
})
export class ColmenaModule {}
