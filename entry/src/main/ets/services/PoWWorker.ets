/**
 * PoW 在 taskpool 后台线程执行，避免阻塞 UI（否则触发 THREAD_BLOCK_6S）。
 * ArkTS 不允许嵌套函数，所以 SHA-256 全部内联在这里。
 */
@Concurrent
export function solvePoW(seed: string, difficulty: number): number {
  const limit: number = difficulty > 26 ? 26 : difficulty;
  const k: number[] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ];

  let counter: number = 0;
  while (counter < 200000000) {
    // ---- 内联 SHA-256(seed + ":" + counter) ----
    const message: string = seed + ":" + counter;
    const bytes: number[] = [];
    for (let i: number = 0; i < message.length; i++) {
      let code: number = message.charCodeAt(i);
      if (code < 0x80) {
        bytes.push(code);
      } else if (code < 0x800) {
        bytes.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f));
      } else if (code >= 0xd800 && code <= 0xdbff) {
        const next: number = message.charCodeAt(i + 1);
        code = 0x10000 + (((code & 0x3ff) << 10) | (next & 0x3ff));
        i++;
        bytes.push(0xf0 | (code >> 18), 0x80 | ((code >> 12) & 0x3f),
          0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
      } else {
        bytes.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
      }
    }
    const bitLength: number = bytes.length * 8;
    bytes.push(0x80);
    while (bytes.length % 64 !== 56) {
      bytes.push(0);
    }
    const high: number = Math.floor(bitLength / 4294967296);
    const low: number = bitLength % 4294967296;
    bytes.push((high >>> 24) & 0xff, (high >>> 16) & 0xff, (high >>> 8) & 0xff, high & 0xff);
    bytes.push((low >>> 24) & 0xff, (low >>> 16) & 0xff, (low >>> 8) & 0xff, low & 0xff);

    let h0: number = 0x6a09e667;
    let h1: number = 0xbb67ae85;
    let h2: number = 0x3c6ef372;
    let h3: number = 0xa54ff53a;
    let h4: number = 0x510e527f;
    let h5: number = 0x9b05688c;
    let h6: number = 0x1f83d9ab;
    let h7: number = 0x5be0cd19;
    const w: number[] = new Array<number>(64).fill(0);

    for (let offset: number = 0; offset < bytes.length; offset += 64) {
      for (let i: number = 0; i < 16; i++) {
        const j: number = offset + i * 4;
        w[i] = ((bytes[j] << 24) | (bytes[j + 1] << 16) | (bytes[j + 2] << 8) | bytes[j + 3]) >>> 0;
      }
      for (let i: number = 16; i < 64; i++) {
        const x: number = w[i - 15];
        const y: number = w[i - 2];
        const s0: number = (((x >>> 7) | (x << 25)) ^ ((x >>> 18) | (x << 14)) ^ (x >>> 3)) >>> 0;
        const s1: number = (((y >>> 17) | (y << 15)) ^ ((y >>> 19) | (y << 13)) ^ (y >>> 10)) >>> 0;
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) >>> 0;
      }
      let a: number = h0;
      let b: number = h1;
      let c: number = h2;
      let d: number = h3;
      let e: number = h4;
      let f: number = h5;
      let g: number = h6;
      let h: number = h7;
      for (let i: number = 0; i < 64; i++) {
        const S1: number = (((e >>> 6) | (e << 26)) ^ ((e >>> 11) | (e << 21)) ^ ((e >>> 25) | (e << 7))) >>> 0;
        const ch: number = (e & f) ^ (~e & g);
        const temp1: number = (h + S1 + ch + k[i] + w[i]) >>> 0;
        const S0: number = (((a >>> 2) | (a << 30)) ^ ((a >>> 13) | (a << 19)) ^ ((a >>> 22) | (a << 10))) >>> 0;
        const maj: number = (a & b) ^ (a & c) ^ (b & c);
        const temp2: number = (S0 + maj) >>> 0;
        h = g;
        g = f;
        f = e;
        e = (d + temp1) >>> 0;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) >>> 0;
      }
      h0 = (h0 + a) >>> 0;
      h1 = (h1 + b) >>> 0;
      h2 = (h2 + c) >>> 0;
      h3 = (h3 + d) >>> 0;
      h4 = (h4 + e) >>> 0;
      h5 = (h5 + f) >>> 0;
      h6 = (h6 + g) >>> 0;
      h7 = (h7 + h) >>> 0;
    }

    const digest: number[] = [];
    for (const value of [h0, h1, h2, h3, h4, h5, h6, h7]) {
      digest.push((value >>> 24) & 0xff, (value >>> 16) & 0xff, (value >>> 8) & 0xff, value & 0xff);
    }

    let bits: number = 0;
    for (const byte of digest) {
      if (byte === 0) {
        bits += 8;
      } else {
        let v: number = byte;
        while (v < 128) {
          bits++;
          v = v << 1;
        }
        break;
      }
    }
    if (bits >= limit) {
      return counter;
    }
    counter++;
  }
  throw new Error("PoW 超时");
}
