import { common } from '@kit.AbilityKit';
import { RecorderEngine } from '../common/RecorderEngine';
import { RecordingStore } from '../common/RecordingStore';

@Component
export struct RecordView {
  @State recording: boolean = false;
  @State seconds: number = 0;

  // Passed in from Index so both tabs share one store.
  store: RecordingStore = new RecordingStore();
  onSaved: () => void = () => {};

  private recorder: RecorderEngine = new RecorderEngine();

  aboutToAppear(): void {
    this.recorder.onTick = (s: number) => {
      this.seconds = s;
    };
  }

  aboutToDisappear(): void {
    if (this.recorder.isRunning()) {
      this.recorder.stop();
    }
  }

  private label(): string {
    const m: number = Math.floor(this.seconds / 60);
    const s: number = this.seconds % 60;
    return `${m < 10 ? `0${m}` : `${m}`}:${s < 10 ? `0${s}` : `${s}`}`;
  }

  private toggle(): void {
    if (this.recording) {
      this.recorder.stop().then(() => {
        this.recording = false;
        this.seconds = 0;
        this.onSaved();
      });
    } else {
      const path: string = this.store.newFilePath();
      this.recorder.start(path).then(() => {
        this.recording = true;
      }).catch(() => {
        console.error('[RecordView] could not start');
      });
    }
  }

  build() {
    Column({ space: 16 }) {
      Text(this.recording ? this.label() : 'Ready')
        .fontSize(this.recording ? 30 : 18)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.recording ? '#1C1B2E' : '#8A8798')

      // Square inside a circle when recording — the familiar stop shape.
      Stack() {
        Circle()
          .width(84)
          .height(84)
          .fill(this.recording ? '#F1EFFC' : '#E5484D')

        if (this.recording) {
          Rect()
            .width(28)
            .height(28)
            .radius(4)
            .fill('#E5484D')
        }
      }
      .width(84)
      .height(84)
      .onClick(() => this.toggle())

      Text(this.recording ? 'Tap to stop' : 'Tap to record')
        .fontSize(12)
        .fontColor('#8A8798')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: 40, right: 40 })
    .backgroundColor(Color.White)
  }
}