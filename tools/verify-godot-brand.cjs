const fs = require('node:fs'), path = require('node:path'), crypto = require('node:crypto');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const brand = path.join(root, 'godot/assets/ui/branding');
const hash = buffer => crypto.createHash('sha256').update(buffer).digest('hex');
const assert = (condition, message) => { if (!condition) throw Error(message); };

async function main() {
  const icon = fs.readFileSync(path.join(brand, 'logo.ico'));
  assert(icon.readUInt16LE(2) === 1 && icon.readUInt16LE(4) === 6, 'ICO must contain six images');
  const expected = new Map();
  for (let i = 0; i < 6; i++) {
    const e = 6 + i * 16, size = icon[e] || 256;
    const image = icon.subarray(icon.readUInt32LE(e + 12), icon.readUInt32LE(e + 12) + icon.readUInt32LE(e + 8));
    const metadata = await sharp(image).metadata();
    assert(metadata.width === size && metadata.height === size && metadata.hasAlpha, 'ICO image size or alpha invalid');
    expected.set(size, hash(image));
  }
  assert([16,32,48,64,128,256].every(size => expected.has(size)), 'Missing icon size');
  const png = await sharp(path.join(brand, 'logo.png')).metadata();
  assert(png.width === 1024 && png.height === 1024 && png.hasAlpha, 'Transparent logo PNG invalid');

  const pe = fs.readFileSync(path.join(root, 'artifacts/godot/windows/灰烬边境.exe'));
  const peStart = pe.readUInt32LE(0x3c), optional = peStart + 24;
  const directory = optional + (pe.readUInt16LE(optional) === 0x20b ? 112 : 96);
  const sections = optional + pe.readUInt16LE(peStart + 20);
  const rvaOffset = rva => {
    for (let i = 0; i < pe.readUInt16LE(peStart + 6); i++) {
      const s = sections + i * 40, address = pe.readUInt32LE(s + 12);
      if (rva >= address && rva < address + Math.max(pe.readUInt32LE(s + 8), pe.readUInt32LE(s + 16)))
        return pe.readUInt32LE(s + 20) + rva - address;
    }
    throw Error('Unmapped resource RVA');
  };
  const base = rvaOffset(pe.readUInt32LE(directory + 16));
  function entries(offset) {
    const p = base + offset, count = pe.readUInt16LE(p + 12) + pe.readUInt16LE(p + 14);
    return Array.from({ length: count }, (_, i) => {
      const q = p + 16 + i * 8, value = pe.readUInt32LE(q + 4);
      return { id: pe.readUInt32LE(q), offset: value & 0x7fffffff, directory: !!(value & 0x80000000) };
    });
  }
  function resource(type, id) {
    const t = entries(0).find(e => e.id === type); assert(t, 'Missing PE resource type ' + type);
    const names = entries(t.offset), name = id === undefined ? names[0] : names.find(e => e.id === id);
    assert(name, 'Missing PE resource ID ' + id);
    const language = entries(name.offset)[0], data = base + language.offset;
    const offset = rvaOffset(pe.readUInt32LE(data));
    return pe.subarray(offset, offset + pe.readUInt32LE(data + 4));
  }
  const group = resource(14), sizes = [];
  for (let i = 0; i < group.readUInt16LE(4); i++) {
    const e = 6 + i * 14, size = group[e] || 256;
    const image = resource(3, group.readUInt16LE(e + 12));
    assert(hash(image) === expected.get(size), 'EXE icon differs from the original at size ' + size);
    sizes.push(size);
  }
  assert(sizes.length === 6, 'EXE must have exactly the six custom icon sizes');
  const report = { passed: true, transparentPng: true, icoSizes: [...expected.keys()], embeddedExeIconSizes: sizes, exactImageMatch: true };
  fs.writeFileSync(path.join(root, 'artifacts/godot/brand-acceptance.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report));
}
main().catch(error => { console.error(error); process.exitCode = 1; });
