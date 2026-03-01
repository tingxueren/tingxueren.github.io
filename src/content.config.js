import { defineCollection, z } from 'astro:content';

const blog = defineCollection({
  schema: z.object({
    title: z.string(),
    date: z.coerce.date(),
    description: z.string().optional().default(''),
    tags: z.array(z.string()).default([]),
    categories: z.array(z.string()).default([]),
    legacyPath: z.string(),
    comments: z.boolean().optional(),
    draft: z.boolean().optional().default(false),
    coverImage: z.string().optional()
  })
});

export const collections = { blog };
