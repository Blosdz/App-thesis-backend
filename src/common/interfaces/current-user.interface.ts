export interface CurrentUser {
  auth_usuario_id: string;
  usuario_id: string;
  email: string;
  rol: 'admin' | 'asesor' | 'estudiante';
  verificado: boolean;
  email_verificado: boolean;
}
