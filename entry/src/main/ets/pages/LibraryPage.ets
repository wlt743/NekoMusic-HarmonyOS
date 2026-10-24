@Component
export struct LibraryPage {
  build() {
    Column() {
      Text("LibraryPage")
        .fontSize(20)
        .fontColor("#999999")
    }
    .width("100%")
    .height("100%")
    .justifyContent(FlexAlign.Center)
    .backgroundColor("#F5F6F8")
  }
}
