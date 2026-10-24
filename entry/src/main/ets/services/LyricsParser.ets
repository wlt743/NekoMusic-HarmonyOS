/** 一行歌词 */
export interface LyricLine {
  time: number;
  text: string;
}

/** LRC 解析，与 iOS 端逻辑一致 */
export class LyricsParser {
  static parse(lrc: string): LyricLine[] {
    const result: LyricLine[] = [];
    if (lrc.length === 0) {
      return result;
    }
    const lines: string[] = lrc.split("\n");
    const pattern: RegExp = /\[(\d{2}):(\d{2})\.?(\d{0,3})\](.*)$/;
    for (const line of lines) {
      const match: RegExpMatchArray | null = line.match(pattern);
      if (match === null) {
        continue;
      }
      const minute: number = Number.parseInt(match[1], 10);
      const second: number = Number.parseInt(match[2], 10);
      let millis: number = 0;
      const msText: string = match[3] ?? "";
      if (msText.length > 0) {
        const raw: number = Number.parseInt(msText, 10);
        millis = msText.length === 2 ? raw / 100 : raw / 1000;
      }
      const text: string = (match[4] ?? "").trim();
      if (text.length === 0) {
        continue;
      }
      result.push({
        time: minute * 60000 + second * 1000 + millis * 1000,
        text: text
      });
    }
    result.sort((a: LyricLine, b: LyricLine) => a.time - b.time);
    return result;
  }

  /** 当前时间对应的歌词行下标，没有则 -1 */
  static indexAt(positionMs: number, lines: LyricLine[]): number {
    if (lines.length === 0) {
      return -1;
    }
    let index: number = -1;
    for (let i: number = 0; i < lines.length; i++) {
      if (positionMs >= lines[i].time) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }
}
