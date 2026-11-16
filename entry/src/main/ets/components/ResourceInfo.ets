@Component
export struct ResourceInfo {
  @State private byteCount: number = 0;
  @State private failed: boolean = false;

  aboutToAppear(): void {
    this.readResource();
  }

  private async readResource(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext();
      if (!context) {
        throw new Error('The component is not attached to an ability.');
      }
      const bytes = await context.resourceManager.getRawFileContent('tone.wav');
      this.byteCount = bytes.byteLength;
    } catch (_) {
      this.failed = true;
    }
  }

  build() {
    Text(this.failed ? $r('app.string.resource_error') : $r('app.string.resource_size', this.byteCount))
      .fontSize(12)
      .fontColor($r('app.color.text_secondary'))
      .textAlign(TextAlign.Center)
  }
}
