export interface CurrentUser {
  usuario_id: string;
  auth_usuario_id: string;
  rol: 'admin' | 'asesor' | 'estudiante';
}
