import { getCollection } from 'astro:content';

export const PER_PAGE = 10;

export async function getAllPosts() {
  const posts = await getCollection('blog', ({ data }) => !data.draft);
  return posts.sort((a, b) => b.data.date.getTime() - a.data.date.getTime());
}

export function getPostUrl(post) {
  return `/${post.data.legacyPath}/`;
}

export function paginate(items, page, perPage = PER_PAGE) {
  const totalPages = Math.max(1, Math.ceil(items.length / perPage));
  const current = Math.min(Math.max(page, 1), totalPages);
  const start = (current - 1) * perPage;
  return {
    totalPages,
    current,
    items: items.slice(start, start + perPage)
  };
}
