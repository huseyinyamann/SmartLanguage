#!/usr/bin/env node
/**
 * assets/words/*.json (dil cifti bazli, aynali) -> data/word_pool.json
 * (dilden bagimsiz kavram listesi).
 *
 * Cikti semasi cok dilli genislemeye gore tasarlandi: yeni bir dil eklemek
 * yeni dokuman degil, var olan kavramlara yeni bir `forms.<dil>` anahtari
 * eklemek demektir. Boylece dil sayisi artarken dokuman sayisi sabit kalir.
 *
 * Kullanim:  node tool/build-pool.js
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const ASSETS = path.join(ROOT, 'assets', 'words');
const OUT = path.join(ROOT, 'data', 'word_pool.json');

/** Kavram kimligi bu dilin yazimindan turetilir. */
const KEY_LANGUAGE = 'en';

/** Hangi dosya hangi yonu tasiyor: dosyaAdi -> [ogrenilen, ana dil]. */
const FILES = {
  'en_tr.json': ['en', 'tr'],
  'tr_en.json': ['tr', 'en'],
};

const slug = (text) =>
  text
    .replace(/İ/g, 'i')
    .replace(/I/g, 'ı')
    .toLowerCase()
    .replace(/[^a-z0-9çğıöşü]+/g, '-')
    .replace(/^-+|-+$/g, '');

/** Bir kavramin butun dil ciftlerini uretir: ['en_tr', 'tr_en', ...] */
const pairsFor = (languages) => {
  const out = [];
  for (const a of languages) {
    for (const b of languages) {
      if (a !== b) out.push(`${a}_${b}`);
    }
  }
  return out.sort();
};

/** conceptKey -> kavram */
const concepts = new Map();

for (const [file, [learning, native]] of Object.entries(FILES)) {
  const full = path.join(ASSETS, file);
  if (!fs.existsSync(full)) {
    console.warn(`atlandi (dosya yok): ${file}`);
    continue;
  }
  const rows = JSON.parse(fs.readFileSync(full, 'utf8'));

  rows.forEach((row, index) => {
    const learningText = (row.term || '').trim();
    const nativeText = (row.translation || '').trim();
    if (!learningText || !nativeText) return;

    // Kavram kimligi her zaman ayni dilden turetilir ki iki dosya ayni
    // kavramda bulussun.
    const keyText = learning === KEY_LANGUAGE ? learningText : nativeText;
    const id = slug(keyText);

    const concept = concepts.get(id) || {
      id,
      conceptKey: keyText,
      pos: null,
      tags: [],
      forms: {},
    };

    // Ogrenilen dilin biçimi
    concept.forms[learning] = {
      text: learningText,
      example: (row.example || '').trim() || null,
      level: row.level || null,
      // Siralama sinyali: dosyadaki sira = onem sirasi.
      rank: concept.forms[learning]?.rank ?? index + 1,
    };

    // Ana dilin biçimi (ornegi cevirisinden gelir)
    const existingNative = concept.forms[native];
    concept.forms[native] = {
      text: nativeText,
      example: (row.exampleTranslation || '').trim() || existingNative?.example || null,
      level: existingNative?.level ?? row.level ?? null,
      rank: existingNative?.rank ?? index + 1,
    };

    concepts.set(id, concept);
  });
}

const pool = [...concepts.values()]
  .map((c) => {
    const languages = Object.keys(c.forms).sort();
    return {
      ...c,
      languages,
      pairs: pairsFor(languages),
      version: 1,
    };
  })
  .sort((a, b) => {
    const ra = a.forms[KEY_LANGUAGE]?.rank ?? 1e9;
    const rb = b.forms[KEY_LANGUAGE]?.rank ?? 1e9;
    return ra - rb || a.id.localeCompare(b.id);
  });

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, `${JSON.stringify(pool, null, 2)}\n`, 'utf8');

const langs = new Set();
pool.forEach((c) => c.languages.forEach((l) => langs.add(l)));
console.log(`${pool.length} kavram yazildi -> ${path.relative(ROOT, OUT)}`);
console.log(`diller: ${[...langs].join(', ')}`);
console.log('ornek:', JSON.stringify(pool[0], null, 2));
