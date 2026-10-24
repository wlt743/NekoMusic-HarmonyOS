@Component
export struct AddToPlaylistButton {
  onTap: () => void = () => {};

  build() {
    Button() {
      Text("+")
        .fontSize(26)
        .fontColor("#DDDDDD")
    }
    .width(56)
    .height(56)
    .backgroundColor(Color.Transparent)
    .onClick(() => {
      this.onTap();
    })
  }
}
