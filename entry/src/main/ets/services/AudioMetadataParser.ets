import { fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

export interface AudioMetadata {
  title: string;
  artist: string;
  duration: number;
}

/** 解析音频文件 ID3v2 标签（标题/歌手） */
export class AudioMetadataParser {
  static async parse(uri: string): Promise<AudioMetadata> {
    const result: AudioMetadata = { title: '', artist: '', duration: 0 };
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const header: ArrayBuffer = new ArrayBuffer(10);
      const readLen: number = fs.readSync(file.fd, header);
      if (readLen < 10) {
        return result;
      }
      const bytes: Uint8Array = new Uint8Array(header);
      // ID3 头：'I' 'D' '3'
      if (bytes[0] !== 0x49 || bytes[1] !== 0x44 || bytes[2] !== 0x33) {
        return result;
      }
      const major: number = bytes[3];
      // 标签总大小（4 字节 synchsafe）
      const size: number = ((bytes[6] & 0x7f) << 21) | ((bytes[7] & 0x7f) << 14) |
        ((bytes[8] & 0x7f) << 7) | (bytes[9] & 0x7f);
      const tagBuffer: ArrayBuffer = new ArrayBuffer(size);
      fs.readSync(file.fd, tagBuffer);
      const tag: Uint8Array = new Uint8Array(tagBuffer);
      AudioMetadataParser.parseFrames(tag, major, result);
    } catch (error) {
      const err = error as Error;
      hilog.error(0x0000, 'NekoMeta', 'parse failed: %{public}s', err.message);
    } finally {
      if (file !== undefined) {
        try {
          fs.closeSync(file);
        } catch (error) {
          // ignore
        }
      }
    }
    return result;
  }

  private static parseFrames(tag: Uint8Array, major: number, result: AudioMetadata): void {
    let offset: number = 0;
    while (offset + 10 < tag.length) {
      const id: string = String.fromCharCode(tag[offset], tag[offset + 1], tag[offset + 2], tag[offset + 3]);
      if (id.charCodeAt(0) === 0) {
        break;
      }
      let frameSize: number = 0;
      if (major === 4) {
        frameSize = ((tag[offset + 4] & 0x7f) << 21) | ((tag[offset + 5] & 0x7f) << 14) |
          ((tag[offset + 6] & 0x7f) << 7) | (tag[offset + 7] & 0x7f);
      } else {
        frameSize = (tag[offset + 4] << 24) | (tag[offset + 5] << 16) |
          (tag[offset + 6] << 8) | tag[offset + 7];
      }
      if (frameSize <= 0 || offset + 10 + frameSize > tag.length) {
        break;
      }
      const content: Uint8Array = tag.subarray(offset + 10, offset + 10 + frameSize);
      if (id === 'TIT2') {
        result.title = AudioMetadataParser.decodeText(content);
      } else if (id === 'TPE1') {
        result.artist = AudioMetadataParser.decodeText(content);
      }
      offset += 10 + frameSize;
    }
  }

  private static decodeText(content: Uint8Array): string {
    if (content.length < 2) {
      return '';
    }
    const encoding: number = content[0];
    const body: Uint8Array = content.subarray(1);
    try {
      if (encoding === 0) {
        // ISO-8859-1
        let text: string = '';
        for (const byte of body) {
          text += String.fromCharCode(byte);
        }
        return text.replace(/\u0000/g, '').trim();
      }
      if (encoding === 3) {
        return AudioMetadataParser.decodeUtf8(body).replace(/\u0000/g, '').trim();
      }
      // UTF-16（1 或 2）
      let text: string = '';
      for (let i: number = 0; i + 1 < body.length; i += 2) {
        const code: number = body[i] | (body[i + 1] << 8);
        if (code !== 0) {
          text += String.fromCharCode(code);
        }
      }
      return text.trim();
    } catch (error) {
      return '';
    }
  }

  private static decodeUtf8(bytes: Uint8Array): string {
    let text: string = '';
    let i: number = 0;
    while (i < bytes.length) {
      const byte: number = bytes[i];
      if (byte < 0x80) {
        text += String.fromCharCode(byte);
        i++;
      } else if ((byte & 0xe0) === 0xc0) {
        const c1: number = bytes[i + 1] & 0x3f;
        text += String.fromCharCode(((byte & 0x1f) << 6) | c1);
        i += 2;
      } else if ((byte & 0xf0) === 0xe0) {
        const c1: number = bytes[i + 1] & 0x3f;
        const c2: number = bytes[i + 2] & 0x3f;
        text += String.fromCharCode(((byte & 0x0f) << 12) | (c1 << 6) | c2);
        i += 3;
      } else {
        i++;
      }
    }
    return text;
  }
}
