#!/usr/bin/env node
/**
 * data/word_pool.json -> Firestore `wordPool` koleksiyonu.
 *
 * Bagimliliksizdir: Firestore REST API'sini dogrudan kullanir, npm install
 * gerekmez. Kimlik icin iki yol destekler:
 *
 *   1. Servis hesabi anahtari:  --key ./prekta-admin.json
 *      (Firebase Console -> Proje ayarlari -> Servis hesaplari)
 *   2. Firebase CLI oturumu (varsayilan): `firebase login` ile acilmis
 *      oturumun jetonu kullanilir.
 *
 * Idempotent: kimlikler kavramdan turetildigi icin tekrar calistirmak
 * kayitlari gunceller, kopya olusturmaz.
 *
 * Kullanim:
 *   node tool/upload-pool.js --dry-run              # sadece dogrula
 *   node tool/upload-pool.js --project prekta       # yukle
 *   node tool/upload-pool.js --prune                # havuzda olmayanlari sil
 */
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');

const ROOT = path.join(__dirname, '..');
const DATA = path.join(ROOT, 'data', 'word_pool.json');
const COLLECTION = 'wordPool';
const BATCH_LIMIT = 400; // REST commit siniri 500

/**
 * Firebase CLI'nin OAuth istemci bilgileri. Bu depo public oldugu icin
 * degerler koda gomulmez; kurulu `firebase-tools` paketinden okunur.
 * Paket yoksa servis hesabi anahtariyla (--key) devam edilir.
 */
function cliOAuthClient() {
  const roots = [
    process.env.APPDATA && path.join(process.env.APPDATA, 'npm', 'node_modules', 'firebase-tools'),
    '/usr/local/lib/node_modules/firebase-tools',
    '/usr/lib/node_modules/firebase-tools',
    path.join(os.homedir(), '.npm-global', 'lib', 'node_modules', 'firebase-tools'),
  ].filter(Boolean);

  for (const root of roots) {
    const file = path.join(root, 'lib', 'api.js');
    if (!fs.existsSync(file)) continue;
    const src = fs.readFileSync(file, 'utf8');
    // firebase-tools: envOverride("FIREBASE_CLIENT_ID", "<deger>")
    const id = src.match(/FIREBASE_CLIENT_ID["']\s*,\s*["']([^"']+)["']/);
    const secret = src.match(/FIREBASE_CLIENT_SECRET["']\s*,\s*["']([^"']+)["']/);
    if (id && secret) return { id: id[1], secret: secret[1] };
  }
  throw new Error(
    'firebase-tools kurulumu bulunamadi (CLI oturumu bu yoldan okunuyor).\n' +
      '  `npm i -g firebase-tools` kur ya da --key ile servis hesabi anahtari ver.',
  );
}

const args = process.argv.slice(2);
const flag = (n) => args.includes(`--${n}`);
const value = (n) => {
  const i = args.indexOf(`--${n}`);
  return i >= 0 ? args[i + 1] : undefined;
};

const dryRun = flag('dry-run');
const prune = flag('prune');
const keyPath = value('key') || process.env.GOOGLE_APPLICATION_CREDENTIALS;
const projectId = value('project') || process.env.FIREBASE_PROJECT || 'smartlanguage';

// ---------------------------------------------------------------- dogrulama
if (!fs.existsSync(DATA)) {
  console.error('Once havuzu uret: node tool/build-pool.js');
  process.exit(1);
}
const pool = JSON.parse(fs.readFileSync(DATA, 'utf8'));

const problems = [];
const ids = new Set();
for (const c of pool) {
  if (!c.id) problems.push(`kimliksiz kayit`);
  if (ids.has(c.id)) problems.push(`tekrarlanan kimlik: ${c.id}`);
  ids.add(c.id);

  const forms = c.forms || {};
  if (Object.keys(forms).length < 2) {
    problems.push(`${c.id}: en az iki dil gerekir`);
  }
  for (const [lang, form] of Object.entries(forms)) {
    if (!form.text || !form.text.trim()) problems.push(`${c.id}.${lang}: metin bos`);
    else if (form.text.length > 80) problems.push(`${c.id}.${lang}: metin cok uzun`);
  }
  for (const pair of c.pairs || []) {
    const [a, b] = pair.split('_');
    if (!forms[a] || !forms[b]) problems.push(`${c.id}: ${pair} icin bicim eksik`);
  }
}

if (problems.length) {
  console.error(`${problems.length} sorun:`);
  problems.slice(0, 20).forEach((p) => console.error('  -', p));
  process.exit(1);
}

const languages = [...new Set(pool.flatMap((c) => c.languages))].sort();
const pairs = [...new Set(pool.flatMap((c) => c.pairs))].sort();
console.log(
  `${pool.length} kavram · diller: ${languages.join(', ')} · ciftler: ${pairs.join(', ')}`,
);

if (dryRun) {
  console.log("--dry-run: Firestore'a yazilmadi.");
  process.exit(0);
}

// ------------------------------------------------------------------- kimlik
const base64url = (buf) =>
  Buffer.from(buf).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

async function tokenFromServiceAccount(file) {
  const sa = JSON.parse(fs.readFileSync(file, 'utf8'));
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = base64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/datastore',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );
  const signature = base64url(
    crypto.createSign('RSA-SHA256').update(`${header}.${claim}`).sign(sa.private_key),
  );

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${header}.${claim}.${signature}`,
    }),
  });
  const json = await res.json();
  if (!json.access_token) throw new Error(`servis hesabi jetonu alinamadi: ${JSON.stringify(json)}`);
  return { token: json.access_token, project: sa.project_id || projectId };
}

async function tokenFromFirebaseCli() {
  const store = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  if (!fs.existsSync(store)) {
    throw new Error('Firebase CLI oturumu bulunamadi. `firebase login` calistir ya da --key ver.');
  }
  const refreshToken = JSON.parse(fs.readFileSync(store, 'utf8'))?.tokens?.refresh_token;
  if (!refreshToken) throw new Error('CLI oturumunda yenileme jetonu yok. `firebase login` calistir.');

  const client = cliOAuthClient();
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: client.id,
      client_secret: client.secret,
    }),
  });
  const json = await res.json();
  if (!json.access_token) throw new Error(`CLI jetonu yenilenemedi: ${JSON.stringify(json)}`);
  return { token: json.access_token, project: projectId };
}

// ------------------------------------------------------- JSON -> Firestore
function toValue(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') {
    return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  }
  if (typeof v === 'string') return { stringValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(toValue) } };
  return { mapValue: { fields: toFields(v) } };
}

const toFields = (obj) =>
  Object.fromEntries(Object.entries(obj).map(([k, v]) => [k, toValue(v)]));

async function commit(baseUrl, token, writes) {
  const res = await fetch(`${baseUrl}:commit`, {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: JSON.stringify({ writes }),
  });
  if (!res.ok) throw new Error(`commit ${res.status}: ${(await res.text()).slice(0, 400)}`);
  return res.json();
}

(async () => {
  const { token, project } = keyPath
    ? await tokenFromServiceAccount(keyPath)
    : await tokenFromFirebaseCli();

  const baseUrl = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
  const docPath = (id) => `projects/${project}/databases/(default)/documents/${COLLECTION}/${id}`;
  console.log(`hedef: ${project} / ${COLLECTION}${keyPath ? ' (servis hesabi)' : ' (CLI oturumu)'}`);

  const now = new Date().toISOString();
  let written = 0;

  for (let i = 0; i < pool.length; i += BATCH_LIMIT) {
    const writes = pool.slice(i, i + BATCH_LIMIT).map((concept) => {
      const { id, ...rest } = concept;
      return {
        update: {
          name: docPath(id),
          fields: toFields({ ...rest, updatedAt: null }),
        },
        updateTransforms: [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }],
      };
    });
    await commit(baseUrl, token, writes);
    written += writes.length;
    console.log(`  ${written}/${pool.length}`);
  }

  if (prune) {
    const res = await fetch(`${baseUrl}/${COLLECTION}?pageSize=1000`, {
      headers: { authorization: `Bearer ${token}` },
    });
    const { documents = [] } = await res.json();
    const extra = documents
      .map((d) => d.name.split('/').pop())
      .filter((id) => !ids.has(id));
    if (extra.length) {
      await commit(baseUrl, token, extra.map((id) => ({ delete: docPath(id) })));
    }
    console.log(`${extra.length} fazla kayit silindi`);
  }

  console.log(`Bitti: ${written} kavram ${COLLECTION} koleksiyonunda (${now}).`);
})().catch((e) => {
  console.error('Yukleme basarisiz:', e.message);
  process.exit(1);
});
