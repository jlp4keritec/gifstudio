import { Router } from 'express';
import * as exploreController from '../controllers/explore-controller.js';
import * as categoriesController from '../controllers/categories-controller.js';

const router = Router();

// Toutes ces routes sont PUBLIQUES (pas de requireAuth)
router.get('/categories', categoriesController.listCategories);
router.get('/explore', exploreController.explore);
router.get('/g/:slug', exploreController.getGifBySlug);

export { router as publicRouter };
