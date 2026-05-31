import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { DatabaseModule } from './database/database.module';
import { AuthModule } from './auth/auth.module';
import { UsuariosModule } from './usuarios/usuarios.module';
import { TesisModule } from './tesis/tesis.module';
import { ReunionesModule } from './reuniones/reuniones.module';
import { PagosModule } from './pagos/pagos.module';
import { DocumentosModule } from './documentos/documentos.module';
import { AsesoresModule } from './asesores/asesores.module';
import { ModulosModule } from './modulos/modulos.module';
import { PlanesModule } from './planes/planes.module';
import { CatalogosModule } from './catalogos/catalogos.module';
import { SuscripcionesModule } from './suscripciones/suscripciones.module';
import { LeadsModule } from './leads/leads.module';
import { GoogleModule } from './google/google.module';
import { AdminModule } from './admin/admin.module';
import { SugerenciasModule } from './sugerencias/sugerencias.module';
import { ObservacionesModule } from './observaciones/observaciones.module';
import { DashboardModule } from './dashboard/dashboard.module';
import { DeepseekModule } from './deepseek/deepseek.module';
import { NotificationsModule } from './notifications/notifications.module';
import { CursosModule } from './cursos/cursos.module';
import { DocGeneratorModule } from './doc-generator/doc-generator.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    DatabaseModule,
    AuthModule,
    UsuariosModule,
    TesisModule,
    ReunionesModule,
    PagosModule,
    DocumentosModule,
    AsesoresModule,
    ModulosModule,
    PlanesModule,
    CatalogosModule,
    SuscripcionesModule,
    LeadsModule,
    GoogleModule,
    AdminModule,
    SugerenciasModule,
    ObservacionesModule,
    DashboardModule,
    DeepseekModule,
    NotificationsModule,
    CursosModule,
    DocGeneratorModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
