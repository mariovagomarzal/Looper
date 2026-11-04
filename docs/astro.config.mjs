// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';
import starlightLinksValidator from 'starlight-links-validator';

// Published on GitHub Pages at https://mariovagomarzal.github.io/Looper
export default defineConfig({
	site: 'https://mariovagomarzal.github.io',
	base: '/Looper',
	trailingSlash: 'always',
	devToolbar: { enabled: false },
	integrations: [
		starlight({
			title: 'Looper',
			description: 'A tiling window manager for macOS with a radial wheel.',
			logo: { src: './src/assets/icon.svg' },
			favicon: '/favicon.svg',
			customCss: ['./src/styles/theme.css'],
			plugins: [starlightLinksValidator()],
			social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/mariovagomarzal/Looper' }],
			lastUpdated: true,
			sidebar: [
				{
					label: 'Start here',
					items: [
						{ label: 'Introduction', slug: 'docs' },
						{ label: 'Installation', slug: 'docs/installation' },
						{ label: 'First steps', slug: 'docs/first-steps' },
					],
				},
				{
					label: 'Concepts',
					items: [
						{ label: 'The tree', slug: 'docs/concepts/tree' },
						{ label: 'Workspaces, monitors and Spaces', slug: 'docs/concepts/workspaces' },
						{ label: 'Binding modes', slug: 'docs/concepts/modes' },
						{ label: 'Commands and the shell', slug: 'docs/concepts/commands' },
					],
				},
				{
					label: 'Guides',
					items: [
						{ label: 'Key bindings', slug: 'docs/guides/key-bindings' },
						{ label: 'Mouse and floating windows', slug: 'docs/guides/mouse' },
						{ label: 'Window rules', slug: 'docs/guides/window-rules' },
						{ label: 'Trackpad gestures', slug: 'docs/guides/gestures' },
						{ label: 'The menu bar', slug: 'docs/guides/menu-bar' },
						{ label: 'The radial wheel', slug: 'docs/guides/wheel' },
					],
				},
				{
					label: 'Reference',
					items: [
						{ label: 'Configuration', slug: 'docs/configuration' },
						{ label: 'Commands', collapsed: true, items: [{ autogenerate: { directory: 'docs/commands' } }] },
					],
				},
				{
					label: 'Development',
					items: [
						{ label: 'Building and releasing', slug: 'docs/development' },
						{ label: 'Architecture', slug: 'docs/architecture' },
					],
				},
				{ label: 'Credits', slug: 'docs/credits' },
			],
		}),
	],
});
