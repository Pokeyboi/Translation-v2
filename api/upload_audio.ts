export const runtime = 'edge';

import { put } from '@vercel/blob';

export async function POST(request: Request): Promise<Response> {
  try {
    const { searchParams } = new URL(request.url);
    const filename = searchParams.get('filename') || `audio-${Date.now()}`;
    const ct = request.headers.get('content-type') || 'application/octet-stream';

    const blob = await put(filename, request.body, {
      access: 'public',
      addRandomSuffix: true,
      contentType: ct,
    });

    return new Response(JSON.stringify(blob), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err?.message || 'upload failed' }), { status: 500 });
  }
}
