# Looper website and docs

The website and docs of Looper, built with [Astro](https://astro.build) and [Starlight](https://starlight.astro.build)
and published at https://mariovagomarzal.github.io/Looper.

- `src/pages/index.astro`: the landing page.
- `src/content/docs/docs/`: the docs. The command pages in `commands/` also generate the CLI help (`just generate`).
- `public/videos/`: the recordings. `src/components/Video.astro` shows a placeholder until `<name>.mp4` exists.

Run `just site` from the repository root for a local server, and `pnpm build` here to build the site and check every
internal link.
