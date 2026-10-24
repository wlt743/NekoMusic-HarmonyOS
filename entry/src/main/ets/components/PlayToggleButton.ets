/**
 * 播放 / 暂停按钮。
 * 直接内联在页面里时，SymbolGlyph 的图标分支和 opacity 都不会随状态刷新，
 * 抽成组件后用 @Prop 触发组件级重建才生效。
 */
@Component
export struct PlayToggleButton {
  @Prop playing: boolean = false;
  onToggle: () => void = () => {};

  build() {
    Stack() {
      if (this.playing) {
        SymbolGlyph($r("sys.symbol.pause_fill"))
          .fontSize(40)
          .fontColor([Color.White])
      } else {
        SymbolGlyph($r("sys.symbol.play_fill"))
          .fontSize(40)
          .fontColor([Color.White])
      }
    }
    .width(80)
    .height(80)
    .onClick(() => {
      this.onToggle();
    })
  }
}
