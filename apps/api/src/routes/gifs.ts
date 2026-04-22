import { Router } from 'express';
import * as gifsController from '../controllers/gifs-controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { gifUpload } from '../middlewares/gif-upload.js';

const router = Router();

router.get('/mine', requireAuth, gifsController.listMyGifs);
router.get('/:id', gifsController.getGif); // public (accès géré dans le controller)
router.post('/', requireAuth, gifUpload.single('gif'), gifsController.saveGif);
router.delete('/:id', requireAuth, gifsController.deleteGif);

export { router as gifsRouter };
