import rss from '@astrojs/rss';
import { getCollection } from 'astro:content';

export async function GET(context) {
  // Exclude drafts from RSS even in dev.
  const posts = (await getCollection('blog', ({ data }) => !data.draft))
    .sort((a, b) => b.data.date - a.data.date);

  return rss({
    title: 'tingxueren.com',
    description: 'reading && thinking',
    site: context.site,
    items: posts.map((post) => ({
      title: post.data.title,
      pubDate: post.data.date,
      description: post.data.description || post.data.title,
      link: `/${post.data.legacyPath}/`
    }))
  });
}
