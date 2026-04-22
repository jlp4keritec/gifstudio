import { Router } from 'express';
import { authRouter } from './auth.js';
import { usersRouter } from './users.js';
import { uploadRouter } from './upload.js';
import { gifsRouter } from './gifs.js';
import { collectionsRouter } from './collections.js';
import { publicRouter } from './public.js';

const router = Router();

router.get('/health', (_req, res) => {
  res.json({
    success: true,
    data: {
      status: 'ok',
      timestamp: new Date().toISOString(),
      service: 'gifstudio-api',
    },
  });
});

// Routes publiques (pas de middleware auth obligatoire)
router.use('/', publicRouter);

// Routes auth + protégées
router.use('/auth', authRouter);
router.use('/admin/users', usersRouter);
router.use('/upload', uploadRouter);
router.use('/gifs', gifsRouter);
router.use('/collections', collectionsRouter);

export { router as apiRouter };
