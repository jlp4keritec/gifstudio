import { Router } from 'express';
import * as uploadController from '../controllers/upload-controller.js';
import { requireAuth } from '../middlewares/auth.js';
import { videoUpload } from '../middlewares/upload.js';

const router = Router();

router.use(requireAuth);

router.post('/video', videoUpload.single('video'), uploadController.uploadVideo);
router.delete('/video/:filename', uploadController.deleteUploadedVideo);

export { router as uploadRouter };
