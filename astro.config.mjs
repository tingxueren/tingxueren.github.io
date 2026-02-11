import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';
import keystatic from '@keystatic/astro';
import node from '@astrojs/node';

const enableKeystatic = process.env.KEYSTATIC_ENABLE === 'true';

const integrations = [sitemap()];
if (enableKeystatic) {
  integrations.push(keystatic());
}

export default defineConfig({
  site: 'https://tingxueren.com',
  trailingSlash: 'always',
  output: enableKeystatic ? 'server' : 'static',
  adapter: enableKeystatic ? node({ mode: 'standalone' }) : undefined,
  integrations,
  markdown: {
    syntaxHighlight: 'prism'
  }
});
