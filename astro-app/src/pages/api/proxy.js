export async function GET({ request, url }) {
  const target = url.searchParams.get('url');
  if (!target) return new Response('missing url', { status: 400 });

  try {
    const resp = await fetch(target, { method: 'GET' });

    const headers = new Headers(resp.headers);
    headers.set('Access-Control-Allow-Origin', '*');
    headers.set('Access-Control-Allow-Methods', 'GET,HEAD,OPTIONS');
    headers.set('Access-Control-Allow-Headers', 'Range,Content-Type');

    return new Response(resp.body, {
      status: resp.status,
      headers,
    });
  } catch (err) {
    return new Response(String(err), { status: 502 });
  }
}

export async function OPTIONS() {
  const headers = new Headers();
  headers.set('Access-Control-Allow-Origin', '*');
  headers.set('Access-Control-Allow-Methods', 'GET,HEAD,OPTIONS');
  headers.set('Access-Control-Allow-Headers', 'Range,Content-Type');
  return new Response(null, { status: 204, headers });
}
