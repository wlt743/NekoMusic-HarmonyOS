/** 收藏按钮：同样是 SymbolGlyph，必须用组件才能随状态重建 */
@Component
export struct FavoriteButton {
  @Prop favorited: boolean = false;
  onToggle: () => void = () => {};

  build() {
    Stack() {
      if (this.favorited) {
        SymbolGlyph($r("sys.symbol.heart_fill"))
          .fontSize(22)
          .fontColor(["#E5484D"])
      } else {
        SymbolGlyph($r("sys.symbol.heart"))
          .fontSize(22)
          .fontColor([Color.White])
      }
    }
    .width(56)
    .height(56)
    .onClick(() => {
      this.onToggle();
    })
  }
}
