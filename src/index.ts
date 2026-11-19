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

		const assetResponse = await env.ASSETS.fetch(new Request(url.toString(), request));

		// Fallback if platform 404 handling is unavailable for this path
		if (assetResponse.status === 404 && !url.pathname.endsWith('/404.html')) {
			const notFoundUrl = new URL(request.url);
			notFoundUrl.pathname = '/404.html';
			const notFound = await env.ASSETS.fetch(new Request(notFoundUrl.toString(), request));
			if (notFound.ok) {
				return new Response(notFound.body, {
					status: 404,
					statusText: 'Not Found',
					headers: notFound.headers,
				});
			}
		}

		return assetResponse;
	},
} satisfies ExportedHandler<Env>;
