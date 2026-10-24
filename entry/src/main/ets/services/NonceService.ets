import { http } from "@kit.NetworkKit";
import { taskpool } from "@kit.ArkTS";
import { solvePoW } from "./PoWWorker";
import { APIConfig } from "./APIConfig";
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 后端防重放：每个动态接口都要一次性 X-Neko-Nonce。
 * 领取流程：换挑战题 -> 解 SHA-256 前导零比特 PoW -> 兑换 nonce。
 *
 * 这里手写同步 SHA-256：cryptoFramework 每次调用都要新建 Md 实例且是异步，
 * PoW 平均要跑上百万次，用它会慢到不可用。
 */
export class NonceService {
  private static instance: NonceService = new NonceService();
  private readNonces: string[] = [];
  private writeNonces: string[] = [];
  private fetchPromise: Promise<void> | undefined = undefined;

  static shared(): NonceService {
    return NonceService.instance;
  }

  /** App 启动时预热：提前换一批 nonce，点歌时就不用等换题了 */
  warmUp(): void {
    if (this.readNonces.length > 0) {
      return;
    }
    this.nextNonce(false).catch(() => {
      // 预热失败无所谓，点歌时会再试
    });
  }

  async nextNonce(forWrite: boolean): Promise<string> {
    hilog.info(0x0000, 'NekoNonce', 'nextNonce write=%{public}s readPool=%{public}d writePool=%{public}d',
      forWrite ? 'true' : 'false', this.readNonces.length, this.writeNonces.length);
    const pool: string[] = forWrite ? this.writeNonces : this.readNonces;
    if (pool.length > 0) {
      const value: string = pool.shift() as string;
      // 低于阈值就后台补充，避免下一次请求又要等 PoW（5 秒起）
      if (pool.length < 3 && this.fetchPromise === undefined) {
        this.refill(forWrite);
      }
      return value;
    }

    // 已有领取在进行中：等它完成后再取，不要并发发第二次请求
    if (this.fetchPromise !== undefined) {
      await this.fetchPromise;
      const shared: string[] = forWrite ? this.writeNonces : this.readNonces;
      if (shared.length > 0) {
        return shared.shift() as string;
      }
    }

    const task: Promise<void> = this.fetchNonces(forWrite ? 4 : 16, forWrite ? 16 : 4);
    this.fetchPromise = task;
    try {
      await task;
    } finally {
      if (this.fetchPromise === task) {
        this.fetchPromise = undefined;
      }
    }

    const fresh: string[] = forWrite ? this.writeNonces : this.readNonces;
    if (fresh.length > 0) {
      return fresh.shift() as string;
    }
    throw new Error("nonce 领取失败");
  }

  /** 后台补充池子，不阻塞当前请求 */
  private refill(forWrite: boolean): void {
    const task: Promise<void> = this.fetchNonces(forWrite ? 0 : 8, forWrite ? 8 : 0);
    this.fetchPromise = task;
    task.then(() => {
      if (this.fetchPromise === task) {
        this.fetchPromise = undefined;
      }
    }).catch(() => {
      if (this.fetchPromise === task) {
        this.fetchPromise = undefined;
      }
    });
  }

  private async fetchNonces(read: number, write: number): Promise<void> {
    try {
      hilog.info(0x0000, 'NekoNonce', 'fetchNonces start r=%{public}d w=%{public}d', read, write);
      const challengeURL: string =
        APIConfig.replayChallengeURL() + "?read=" + read + "&write=" + write;
      const challengeText: string = await this.rawGet(challengeURL);
      hilog.info(0x0000, 'NekoNonce', 'challenge ok len=%{public}d', challengeText.length);
      const challengeJson: ChallengeResponse = JSON.parse(challengeText) as ChallengeResponse;
      if (!challengeJson.success) {
        throw new Error("换取挑战题失败");
      }
      const data: ChallengeData = challengeJson.data;
      if (data.algorithm !== "sha256-leading-zero-bits") {
        throw new Error("未支持的 PoW 算法");
      }

      hilog.info(0x0000, 'NekoNonce', 'pow start difficulty=%{public}d', data.difficulty);
      const proof: number = await taskpool.execute(solvePoW, data.seed, data.difficulty) as number;
      hilog.info(0x0000, 'NekoNonce', 'pow done proof=%{public}d', proof);

      const nonceURL: string = APIConfig.replayNonceURL() +
        "?challenge=" + encodeURIComponent(data.challenge) +
        "&proof=" + proof + "&read=" + read + "&write=" + write;
      hilog.info(0x0000, 'NekoNonce', 'nonce request start');
      const nonceText: string = await this.rawGet(nonceURL);
      hilog.info(0x0000, 'NekoNonce', 'nonce ok len=%{public}d', nonceText.length);
      const nonceJson: NonceResponse = JSON.parse(nonceText) as NonceResponse;
      if (!nonceJson.success) {
        throw new Error("兑换 nonce 失败");
      }
      const nonces: NoncePayload = nonceJson.data.nonces;
      if (nonces.read !== undefined) {
        for (const item of nonces.read) {
          this.readNonces.push(item);
        }
      }
      if (nonces.write !== undefined) {
        for (const item of nonces.write) {
          this.writeNonces.push(item);
        }
      }
    } finally {
      // nothing
    }
  }

  private async rawGet(url: string): Promise<string> {
    const request: http.HttpRequest = http.createHttp();
    try {
      const response: http.HttpResponse = await request.request(url, {
        method: http.RequestMethod.GET,
        header: APIConfig.clientHeaders(),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 20000
      });
      if (response.responseCode !== 200) {
        throw new Error("nonce 请求失败: " + response.responseCode);
      }
      return response.result as string;
    } finally {
      request.destroy();
    }
  }

  /**
   * 找最小的 counter 让 sha256(seed:counter) 前导零比特 >= difficulty。
   * 分片执行并主动让出主线程：整段同步跑会触发 THREAD_BLOCK_6S 被系统杀掉。
   */
  private async solve(seed: string, difficulty: number): Promise<number> {
    const limit: number = difficulty > 26 ? 26 : difficulty;
    let counter: number = 0;
    while (counter < 200000000) {
      const chunkEnd: number = counter + 20000;
      while (counter < chunkEnd) {
        const digest: number[] = this.sha256(seed + ":" + counter);
        if (this.leadingZeroBits(digest) >= limit) {
          return counter;
        }
        counter++;
      }
      await new Promise<void>((resolve) => setTimeout(() => resolve(), 0));
    }
    throw new Error("PoW 超时");
  }

  private leadingZeroBits(digest: number[]): number {
    let bits: number = 0;
    for (const byte of digest) {
      if (byte === 0) {
        bits += 8;
      } else {
        let b: number = byte;
        while (b < 128) {
          bits++;
          b = b << 1;
        }
        break;
      }
    }
    return bits;
  }

  // MARK: - 同步 SHA-256（纯 ArkTS 实现）

  private sha256(message: string): number[] {
    const bytes: number[] = this.utf8Bytes(message);
    const length: number = bytes.length;
    const bitLength: number = length * 8;

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

    const k: number[] = SHA256_K;
    const w: number[] = new Array<number>(64).fill(0);

    for (let offset: number = 0; offset < bytes.length; offset += 64) {
      for (let i: number = 0; i < 16; i++) {
        const j: number = offset + i * 4;
        w[i] = ((bytes[j] << 24) | (bytes[j + 1] << 16) | (bytes[j + 2] << 8) | bytes[j + 3]) >>> 0;
      }
      for (let i: number = 16; i < 64; i++) {
        const s0: number = this.rotr(w[i - 15], 7) ^ this.rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
        const s1: number = this.rotr(w[i - 2], 17) ^ this.rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
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
        const S1: number = this.rotr(e, 6) ^ this.rotr(e, 11) ^ this.rotr(e, 25);
        const ch: number = (e & f) ^ (~e & g);
        const temp1: number = (h + S1 + ch + k[i] + w[i]) >>> 0;
        const S0: number = this.rotr(a, 2) ^ this.rotr(a, 13) ^ this.rotr(a, 22);
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

    const result: number[] = [];
    for (const value of [h0, h1, h2, h3, h4, h5, h6, h7]) {
      result.push((value >>> 24) & 0xff, (value >>> 16) & 0xff, (value >>> 8) & 0xff, value & 0xff);
    }
    return result;
  }

  private rotr(value: number, bits: number): number {
    return ((value >>> bits) | (value << (32 - bits))) >>> 0;
  }

  private utf8Bytes(text: string): number[] {
    const result: number[] = [];
    for (let i: number = 0; i < text.length; i++) {
      let code: number = text.charCodeAt(i);
      if (code < 0x80) {
        result.push(code);
      } else if (code < 0x800) {
        result.push(0xc0 | (code >> 6), 0x80 | (code & 0x3f));
      } else if (code >= 0xd800 && code <= 0xdbff) {
        const next: number = text.charCodeAt(i + 1);
        code = 0x10000 + (((code & 0x3ff) << 10) | (next & 0x3ff));
        i++;
        result.push(0xf0 | (code >> 18), 0x80 | ((code >> 12) & 0x3f),
          0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
      } else {
        result.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f));
      }
    }
    return result;
  }
}

const SHA256_K: number[] = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
];

interface ChallengeData {
  challenge: string;
  seed: string;
  difficulty: number;
  algorithm: string;
}

interface ChallengeResponse {
  success: boolean;
  message: string;
  data: ChallengeData;
}

interface NoncePayload {
  read?: string[];
  write?: string[];
}

interface NonceData {
  nonces: NoncePayload;
  expiresIn: number;
}

interface NonceResponse {
  success: boolean;
  message: string;
  data: NonceData;
}
