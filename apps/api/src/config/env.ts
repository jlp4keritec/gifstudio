import 'dotenv/config';
import { z } from 'zod';

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),

  DATABASE_URL: z.string().url(),

  API_PORT: z.coerce.number().int().positive().default(4000),
  API_HOST: z.string().default('localhost'),

  JWT_SECRET: z.string().min(16, 'JWT_SECRET must be at least 16 characters'),
  JWT_EXPIRES_IN: z.string().default('24h'),
  BCRYPT_COST: z.coerce.number().int().min(10).max(15).default(12),

  ADMIN_EMAIL: z.string().email(),
  ADMIN_PASSWORD: z.string().min(6),

  STORAGE_ROOT: z.string().default('./storage'),
  MAX_UPLOAD_SIZE_MB: z.coerce.number().int().positive().default(50),

  CORS_ORIGIN: z.string().default('http://localhost:3000'),

  FORCE_PASSWORD_CHANGE: z
    .string()
    .default('true')
    .transform((val) => val.toLowerCase() === 'true'),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('❌ Invalid environment variables:');
  console.error(parsed.error.format());
  process.exit(1);
}

export const env = parsed.data;
export type Env = z.infer<typeof envSchema>;
