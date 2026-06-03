import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

// ESM equivalent of CommonJS __dirname — package.json is "type": "module"
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const SUPABASE_URL = process.env.VITE_SUPABASE_URL ?? '';
const SUPABASE_KEY = process.env.VITE_SUPABASE_PUBLISHABLE_KEY ?? '';
const USER_EMAIL = process.env.E2E_USER_EMAIL ?? '';
const USER_PASSWORD = process.env.E2E_USER_PASSWORD ?? '';

async function globalSetup() {
  if (!SUPABASE_URL || !SUPABASE_KEY) {
    throw new Error('Missing VITE_SUPABASE_URL or VITE_SUPABASE_PUBLISHABLE_KEY env vars');
  }
  if (!USER_EMAIL || !USER_PASSWORD) {
    throw new Error('Missing E2E_USER_EMAIL or E2E_USER_PASSWORD env vars');
  }

  // Authenticate via Supabase REST API (deterministic, no browser needed)
  const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: SUPABASE_KEY,
    },
    body: JSON.stringify({ email: USER_EMAIL, password: USER_PASSWORD }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Supabase auth failed (${res.status}): ${body}`);
  }

  const session = await res.json();

  // Build storageState that Playwright injects into every browser context.
  // Supabase JS client reads auth from localStorage, so we set the
  // sb-<ref>-auth-token key that it expects.
  const ref = new URL(SUPABASE_URL).hostname.split('.')[0];
  const storageKey = `sb-${ref}-auth-token`;

  const origin = process.env.BASE_URL || 'http://localhost:4173';

  const storageState = {
    cookies: [],
    origins: [
      {
        origin,
        localStorage: [
          {
            name: storageKey,
            value: JSON.stringify(session),
          },
        ],
      },
    ],
  };

  const authDir = path.join(__dirname, '.auth');
  fs.mkdirSync(authDir, { recursive: true });
  fs.writeFileSync(
    path.join(authDir, 'user.json'),
    JSON.stringify(storageState, null, 2),
  );
}

export default globalSetup;
