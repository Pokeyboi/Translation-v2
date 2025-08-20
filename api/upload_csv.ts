export const runtime = 'edge';

import { put } from '@vercel/blob';

export async function POST(request: Request): Promise<Response> {
  try {
    const { searchParams } = new URL(request.url);
    const filename = searchParams.get('filename') || `upload-${Date.now()}.csv`;

    const blob = await put(filename, request.body, {
      access: 'public',
      addRandomSuffix: true,
      contentType: 'text/csv; charset=utf-8',
    });

    return new Response(JSON.stringify(blob), { status: 200, headers: { 'content-type': 'application/json' } });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err?.message || 'upload failed' }), { status: 500 });
  }
}
