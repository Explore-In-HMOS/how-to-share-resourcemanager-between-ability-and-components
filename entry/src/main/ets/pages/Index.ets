import { AudioService } from '../service/AudioService';
import { ResourceInfo } from '../components/ResourceInfo';

@Entry
@Component
struct Index {
  @State private ready: boolean = false;
  @State private busy: boolean = false;
  @State private failed: boolean = false;
  @State private initializationCount: number = 0;
  private visible: boolean = false;
  private service: AudioService = AudioService.getInstance();

  onPageShow(): void {
    this.visible = true;
    this.prepare();
  }

  onPageHide(): void {
    this.visible = false;
  }

  aboutToDisappear(): void {
    this.visible = false;
  }

  private async prepare(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.failed = false;
    try {
      const context = this.getUIContext().getHostContext();
      if (!context) {
        throw new Error('The page is not attached to an ability.');
      }
      // Deliberately concurrent: both calls, plus the ability call, share one init.
      await Promise.all([
        this.service.initialize(context.resourceManager),
        this.service.initialize(context.resourceManager)
      ]);
      if (this.visible) {
        this.ready = true;
        this.initializationCount = this.service.getInitializationCount();
      }
    } catch (_) {
      this.ready = false;
      this.failed = true;
    } finally {
      this.busy = false;
    }
  }

  private async play(): Promise<void> {
    this.busy = true;
    this.failed = false;
    try {
      const context = this.getUIContext().getHostContext();
      if (!context) {
        throw new Error('The page is not attached to an ability.');
      }
      await this.service.play(context.resourceManager);
    } catch (_) {
      this.failed = true;
      this.ready = false;
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column({ space: 9 }) {
      Text($r('app.string.EntryAbility_label'))
        .fontSize($r('app.float.page_text_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))

      Text(this.failed ? $r('app.string.audio_error') :
        (this.ready ? $r('app.string.audio_ready') : $r('app.string.audio_loading')))
        .fontSize(14)
        .fontColor(this.failed ? $r('app.color.status_error') : $r('app.color.accent'))
        .textAlign(TextAlign.Center)

      Button($r('app.string.play_tone'))
        .width(160)
        .height(40)
        .backgroundColor($r('app.color.accent'))
        .fontColor($r('app.color.page_background'))
        .enabled(this.ready && !this.busy)
        .onClick(() => { this.play(); })

      Button(this.failed ? $r('app.string.retry') : $r('app.string.check_guard'))
        .width(160)
        .height(36)
        .fontSize(13)
        .backgroundColor($r('app.color.surface'))
        .enabled(!this.busy)
        .onClick(() => { this.prepare(); })

      Text($r('app.string.initialization_count', this.initializationCount))
        .fontSize(12)
        .fontColor($r('app.color.text_secondary'))
      ResourceInfo()
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 28, right: 28, top: 24, bottom: 24 })
    .backgroundColor($r('app.color.page_background'))
  }
}
