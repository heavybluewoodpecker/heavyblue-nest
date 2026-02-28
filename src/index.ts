/**
 * Static site Worker.
 *
 * Static files live in `public/` and are bound via `wrangler.jsonc` as `env.ASSETS`.
 */

export default {
	async fetch(request, env): Promise<Response> {
		if (request.method !== 'GET' && request.method !== 'HEAD') {
			return new Response('Method Not Allowed', { status: 405 });
		}

		const url = new URL(request.url);
		if (url.pathname === '/') url.pathname = '/index.html';

		return env.ASSETS.fetch(new Request(url.toString(), request));
	},
} satisfies ExportedHandler<Env>;
