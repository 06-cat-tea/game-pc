const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const brand = path.join(root, 'godot/assets/ui/branding');

async function main() {
  const source = fs.readFileSync(path.join(brand, 'logo.svg'));
  await sharp(source).resize(1024, 1024).png().toFile(path.join(brand, 'logo.png'));
  const sizes = [16, 32, 48, 64, 128, 256];
  const images = await Promise.all(sizes.map(size => sharp(source).resize(size, size).png().toBuffer()));
  const header = Buffer.alloc(6 + 16 * sizes.length);
  header.writeUInt16LE(1, 2); header.writeUInt16LE(sizes.length, 4);
  let offset = header.length;
  sizes.forEach((size, i) => {
    const entry = 6 + i * 16;
    header[entry] = size === 256 ? 0 : size;
    header[entry + 1] = header[entry];
    header.writeUInt16LE(1, entry + 4); header.writeUInt16LE(32, entry + 6);
    header.writeUInt32LE(images[i].length, entry + 8); header.writeUInt32LE(offset, entry + 12);
    offset += images[i].length;
  });
  fs.writeFileSync(path.join(brand, 'logo.ico'), Buffer.concat([header, ...images]));
  const output = path.join(root, 'artifacts/godot'); fs.mkdirSync(output, { recursive: true });
  const large = await sharp(source).resize(240, 240).png().toBuffer();
  await sharp({ create: { width: 640, height: 340, channels: 4, background: '#f5f2eb' } })
    .composite([
      { input: Buffer.from('<svg width="320" height="340"><path fill="#27313b" d="M0 0h320v340H0z"/></svg>'), left: 320, top: 0 },
      { input: large, left: 40, top: 25 }, { input: large, left: 360, top: 25 },
      ...[16,32,48].flatMap((size,i) => [
        { input: images[sizes.indexOf(size)], left: 78+i*65, top: 280+(48-size)/2 },
        { input: images[sizes.indexOf(size)], left: 398+i*65, top: 280+(48-size)/2 }
      ])
    ]).png().toFile(path.join(output, 'brand-preview.png'));
  console.log('Original SVG, transparent PNG and six-size ICO saved in ' + brand);
}
main().catch(error => { console.error(error); process.exitCode = 1; });
