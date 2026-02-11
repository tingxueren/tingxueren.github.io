import { collection, config, fields } from '@keystatic/core';

const storageKind = process.env.KEYSTATIC_STORAGE_KIND;
const githubRepo = process.env.KEYSTATIC_GITHUB_REPO;

export default config({
  storage:
    storageKind === 'github' && githubRepo
      ? {
          kind: 'github',
          repo: githubRepo
        }
      : { kind: 'local' },
  collections: {
    blog: collection({
      label: 'Blog Posts',
      path: 'src/content/blog/*',
      slugField: 'postSlug',
      format: { contentField: 'content' },
      columns: ['title', 'date', 'legacyPath', 'draft'],
      entryLayout: 'content',
      schema: {
        postSlug: fields.slug({
          name: {
            label: 'Filename slug',
            description: 'Used as the markdown filename under src/content/blog/'
          },
          slug: {
            label: 'Filename'
          }
        }),
        title: fields.text({ label: 'Title', validation: { isRequired: true } }),
        date: fields.datetime({
          label: 'Published At',
          validation: { isRequired: true }
        }),
        description: fields.text({ label: 'Description', multiline: true }),
        slug: fields.text({
          label: 'URL Slug',
          description: 'Used by existing routing logic; keep synced with legacyPath',
          validation: { isRequired: true }
        }),
        legacyPath: fields.text({
          label: 'Legacy Path',
          description: 'Example: 2016/11/05/my-post',
          validation: { isRequired: true }
        }),
        tags: fields.array(fields.text({ label: 'Tag' }), { label: 'Tags' }),
        categories: fields.array(fields.text({ label: 'Category' }), {
          label: 'Categories'
        }),
        comments: fields.checkbox({
          label: 'Enable comments',
          defaultValue: false
        }),
        draft: fields.checkbox({ label: 'Draft', defaultValue: false }),
        content: fields.markdoc({ label: 'Content' })
      }
    })
  }
});
