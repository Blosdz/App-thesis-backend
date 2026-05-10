import { Module } from '@nestjs/common';
import { CryptoModule } from '../common/crypto/crypto.module';
import { DatabaseModule } from '../database/database.module';
import { UsuariosController } from './usuarios.controller';
import { UsuariosService } from './usuarios.service';

@Module({
  imports: [DatabaseModule, CryptoModule],
  controllers: [UsuariosController],
  providers: [UsuariosService],
  exports: [UsuariosService],
})
export class UsuariosModule {}
