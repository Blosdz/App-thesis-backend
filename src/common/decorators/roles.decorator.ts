import { SetMetadata } from '@nestjs/common';
import type { CurrentUser } from '../interfaces/current-user.interface';

export const ROLES_KEY = 'roles';
export const Roles = (...roles: CurrentUser['rol'][]) =>
  SetMetadata(ROLES_KEY, roles);
