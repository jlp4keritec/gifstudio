import type { Metadata } from 'next';
import { Providers } from './providers';
import './globals.css';

export const metadata: Metadata = {
  title: {
    default: 'GifStudio — Créer et partager des GIFs',
    template: '%s — GifStudio',
  },
  description: 'Créez des GIFs animés à partir de vos vidéos et partagez-les en un clic.',
  applicationName: 'GifStudio',
  formatDetection: {
    telephone: false,
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fr">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
