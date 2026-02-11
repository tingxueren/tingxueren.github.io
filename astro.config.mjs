import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://tingxueren.com',
  trailingSlash: 'always',
  integrations: [sitemap()],
  markdown: {
    syntaxHighlight: 'prism'
  }
});
