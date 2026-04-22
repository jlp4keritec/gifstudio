export type UserRole = 'admin' | 'moderator' | 'user';

export interface User {
  id: string;
  email: string;
  role: UserRole;
  mustChangePassword: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AuthTokenPayload {
  userId: string;
  email: string;
  role: UserRole;
}
