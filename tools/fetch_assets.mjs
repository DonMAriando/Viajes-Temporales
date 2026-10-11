import {createHash} from "node:crypto";
import {mkdir, readFile, writeFile} from "node:fs/promises";
import {dirname, resolve, sep} from "node:path";
import {fileURLToPath} from "node:url";
import {inflateRawSync} from "node:zlib";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const config = JSON.parse(await readFile(resolve(root, "tools", "assets.config.json"), "utf8"));
const lockPath = resolve(root, "assets", "manifest.json");
let previous = {assets: []};
try {
  previous = JSON.parse(await readFile(lockPath, "utf8"));
} catch (error) {
  if (error.code !== "ENOENT") throw error;
}
const lockedFiles = new Map(previous.assets.flatMap(a => a.files).map(f => [f.path, f]));
const manifest = {version: 1, license_policy: "CC0-1.0 assets; OFL-1.1 fonts", assets: []};
const headers = {"User-Agent": "Meridian-ViajesTemporales-AssetTools/1.0"};

function localPath(relative) {
  const result = resolve(root, ...relative.split("/"));
  if (!result.startsWith(root + sep)) throw new Error(`Path outside project: ${relative}`);
  return result;
}

async function request(url) {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const response = await fetch(url, {headers, signal: AbortSignal.timeout(120000)});
      if (!response.ok) throw new Error(`HTTP ${response.status}: ${url}`);
      return response;
    } catch (error) {
      if (attempt === 2) throw error;
      console.error(`Download retry ${attempt + 1}: ${error.message}`);
      await new Promise(r => setTimeout(r, 1000 * (attempt + 1)));
    }
  }
}

async function download(relative, spec) {
  const target = localPath(relative);
  let bytes;
  try {
    bytes = await readFile(target);
  } catch (error) {
    if (error.code !== "ENOENT") throw error;
    bytes = Buffer.from(await (await request(spec.url)).arrayBuffer());
  }
  const digest = createHash("sha256").update(bytes).digest("hex");
  const expected = lockedFiles.get(relative);
  if (expected && expected.sha256 !== digest) throw new Error(`SHA256 mismatch: ${relative}`);
  if (spec.md5 && createHash("md5").update(bytes).digest("hex") !== spec.md5) {
    throw new Error(`Poly Haven MD5 mismatch: ${relative}`);
  }
  if (spec.size && spec.size !== bytes.length) throw new Error(`Size mismatch: ${relative}`);
  await mkdir(dirname(target), {recursive: true});
  await writeFile(target, bytes);
  return {path: relative, url: spec.url, size: bytes.length, sha256: digest};
}

console.log("Powered by Poly Haven. Downloading licensed assets, with checksum verification.");
for (const kind of ["textures", "models"]) {
  for (const spec of config[kind]) {
    console.log(`${kind}: ${spec.id} (${spec.resolution})`);
    const files = await (await request(`https://api.polyhaven.com/files/${spec.id}`)).json();
    const bundle = files.gltf?.[spec.resolution]?.gltf;
    if (!bundle?.include) throw new Error(`No glTF bundle for ${spec.id}/${spec.resolution}`);
    const folder = `assets/${kind}/${spec.name}`;
    const entry = {
      id: spec.id, name: spec.name, type: kind, license: "CC0-1.0",
      source: `https://polyhaven.com/a/${spec.id}`, files: []
    };
    if (kind === "models") {
      entry.scene = `${folder}/${spec.id}_${spec.resolution}.gltf`;
      entry.files.push(await download(entry.scene, bundle));
    }
    for (const [relative, file] of Object.entries(bundle.include)) {
      if (kind === "textures" && !relative.match(/\.(jpg|png)$/i)) continue;
      entry.files.push(await download(`${folder}/${relative}`, file));
    }
    manifest.assets.push(entry);
  }
}

for (const source of config.sources) {
  console.log(`Source: ${source.name}`);
  manifest.assets.push({
    id: source.name, type: "source", license: source.license, source: source.url,
    files: [await download(source.path, source)]
  });
}
for (const archive of config.archives ?? []) {
  console.log(`CC0 archive: ${archive.id}`);
  const archiveFile = await download(archive.path, archive);
  const bytes = await readFile(localPath(archive.path));
  const entries = new Map();
  let end = bytes.length - 22;
  while (end >= Math.max(0, bytes.length - 65558) && bytes.readUInt32LE(end) !== 0x06054b50) end--;
  if (end < 0) throw new Error(`Invalid ZIP: ${archive.id}`);
  let cursor = bytes.readUInt32LE(end + 16);
  const count = bytes.readUInt16LE(end + 10);
  for (let i = 0; i < count; i++) {
    if (bytes.readUInt32LE(cursor) !== 0x02014b50) throw new Error("Invalid ZIP directory");
    const nameLength = bytes.readUInt16LE(cursor + 28);
    const extraLength = bytes.readUInt16LE(cursor + 30);
    const commentLength = bytes.readUInt16LE(cursor + 32);
    const name = bytes.toString("utf8", cursor + 46, cursor + 46 + nameLength);
    entries.set(name, {
      method: bytes.readUInt16LE(cursor + 10), size: bytes.readUInt32LE(cursor + 20),
      offset: bytes.readUInt32LE(cursor + 42)
    });
    cursor += 46 + nameLength + extraLength + commentLength;
  }
  const entry = {id: archive.id, type: "archive", license: archive.license, source: archive.source, files: [archiveFile]};
  for (const member of archive.members) {
    const spec = entries.get(member.entry);
    if (!spec) throw new Error(`Missing archive member: ${member.entry}`);
    const offset = spec.offset;
    if (bytes.readUInt32LE(offset) !== 0x04034b50) throw new Error("Invalid ZIP local header");
    const start = offset + 30 + bytes.readUInt16LE(offset + 26) + bytes.readUInt16LE(offset + 28);
    const compressed = bytes.subarray(start, start + spec.size);
    if (![0, 8].includes(spec.method)) throw new Error(`Unsupported ZIP compression: ${spec.method}`);
    const extracted = spec.method === 8 ? inflateRawSync(compressed) : compressed;
    const sha256 = createHash("sha256").update(extracted).digest("hex");
    if (lockedFiles.has(member.path) && lockedFiles.get(member.path).sha256 !== sha256) {
      throw new Error(`Extracted asset checksum mismatch: ${member.path}`);
    }
    await mkdir(dirname(localPath(member.path)), {recursive: true});
    await writeFile(localPath(member.path), extracted);
    entry.files.push({path: member.path, url: `${archive.url}#${member.entry}`, size: extracted.length, sha256});
  }
  manifest.assets.push(entry);
}
await mkdir(dirname(lockPath), {recursive: true});
await writeFile(lockPath, JSON.stringify(manifest, null, 2) + "\n");
console.log(`Asset manifest written: ${manifest.assets.length} licensed resources.`);
