import { Router } from 'express';
import { authRouter } from './auth';
import { usersRouter } from './users';
import { uploadRouter } from './upload';
import { gifsRouter } from './gifs';
import { collectionsRouter } from './collections';
import { publicRouter } from './public';

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
