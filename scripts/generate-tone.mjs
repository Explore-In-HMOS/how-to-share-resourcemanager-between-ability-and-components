import { mkdirSync, writeFileSync } from 'node:fs';

// Original, reproducible one-second PCM tone, without downloaded media.
const sampleRate = 22050;
const samples = sampleRate;
const wav = Buffer.alloc(44 + samples * 2);
wav.write('RIFF', 0);
wav.writeUInt32LE(wav.length - 8, 4);
wav.write('WAVEfmt ', 8);
wav.writeUInt32LE(16, 16);
wav.writeUInt16LE(1, 20);
wav.writeUInt16LE(1, 22);
wav.writeUInt32LE(sampleRate, 24);
wav.writeUInt32LE(sampleRate * 2, 28);
wav.writeUInt16LE(2, 32);
wav.writeUInt16LE(16, 34);
wav.write('data', 36);
wav.writeUInt32LE(samples * 2, 40);
for (let i = 0; i < samples; i++) {
  const envelope = Math.min(1, i / 1100, (samples - i - 1) / 2200);
  wav.writeInt16LE(Math.round(Math.sin(2 * Math.PI * 440 * i / sampleRate) * envelope * 5000), 44 + i * 2);
}
const directory = new URL('../entry/src/main/resources/rawfile/', import.meta.url);
mkdirSync(directory, { recursive: true });
writeFileSync(new URL('tone.wav', directory), wav);
console.log(`Generated tone.wav (${wav.length} bytes)`);
