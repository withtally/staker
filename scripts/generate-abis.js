// SPDX-License-Identifier: MIT
// Generates ABI-only JSON files from Foundry build artifacts (./out)

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

// Derive __dirname in ES-module context
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Directory that contains Foundry build artifacts
const OUT_DIR = path.join(__dirname, '..', 'out');
// Output directory for abi-only json files
const ABI_DIR = path.join(__dirname, '..', 'abi');

if (!fs.existsSync(ABI_DIR)) {
  fs.mkdirSync(ABI_DIR);
}

function recurseDir(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      recurseDir(fullPath);
    } else if (entry.isFile() && entry.name.endsWith('.json')) {
      const artifact = JSON.parse(fs.readFileSync(fullPath, 'utf8'));
      if (artifact.abi) {
        const outPath = path.join(ABI_DIR, path.basename(entry.name));
        fs.writeFileSync(outPath, JSON.stringify(artifact.abi, null, 2));
      }
    }
  }
}

recurseDir(OUT_DIR);
console.log(`ABI files written to ${ABI_DIR}`); 