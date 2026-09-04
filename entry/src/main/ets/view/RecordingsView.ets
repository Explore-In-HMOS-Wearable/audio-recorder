import { Recording, RecordingStore } from '../common/RecordingStore';
import { PlayerEngine } from '../common/PlayerEngine';

@Component
export struct RecordingsView {
  @Link items: Recording[];

  store: RecordingStore = new RecordingStore();
  onChanged: () => void = () => {};

  @State playingPath: string = '';

  private player: PlayerEngine = new PlayerEngine();

  aboutToAppear(): void {
    this.player.onFinished = () => {
      this.playingPath = '';
    };
  }

  aboutToDisappear(): void {
    this.player.stop();
  }

  /** Bytes -> seconds, using the known format (16 kHz, mono, 16-bit). */
  private durationOf(r: Recording): string {
    const audioBytes: number = r.sizeBytes > 44 ? r.sizeBytes - 44 : 0;
    const total: number = Math.floor(audioBytes / 32000);
    const m: number = Math.floor(total / 60);
    const s: number = total % 60;
    return `${m < 10 ? `0${m}` : `${m}`}:${s < 10 ? `0${s}` : `${s}`}`;
  }

  private clockOf(r: Recording): string {
    const d: Date = new Date(r.createdAt);
    const h: number = d.getHours();
    const m: number = d.getMinutes();
    return `${h < 10 ? `0${h}` : `${h}`}:${m < 10 ? `0${m}` : `${m}`}`;
  }

  private toggle(r: Recording): void {
    if (this.playingPath === r.path) {
      this.player.stop();
      this.playingPath = '';
    } else {
      this.player.play(r.path);
      this.playingPath = r.path;
    }
  }

  private remove(r: Recording): void {
    if (this.playingPath === r.path) {
      this.player.stop();
      this.playingPath = '';
    }
    this.store.delete(r.path);
    this.onChanged();
  }

  @Builder
  row(r: Recording) {
    Row({ space: 12 }) {
      Stack() {
        Circle()
          .width(38)
          .height(38)
          .fill(this.playingPath === r.path ? '#7360F2' : '#F1EFFC')
        SymbolGlyph(this.playingPath === r.path
          ? $r('sys.symbol.pause_fill')
          : $r('sys.symbol.play_fill'))
          .fontSize(16)
          .fontColor([this.playingPath === r.path ? Color.White : '#7360F2'])
      }
      .width(38)
      .height(38)
      .onClick(() => this.toggle(r))

      Column({ space: 2 }) {
        Text(this.durationOf(r))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1B2E')
        Text(this.clockOf(r))
          .fontSize(11)
          .fontColor('#8A8798')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.trash'))
        .fontSize(16)
        .fontColor(['#8A8798'])
        .onClick(() => this.remove(r))
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
  }

  build() {
    if (this.items.length === 0) {
      Column({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.mic_fill'))
          .fontSize(34)
          .fontColor(['#D6D2EC'])
        Text('No recordings yet')
          .fontSize(13)
          .fontColor('#8A8798')
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor(Color.White)
    } else {
      List() {
        ForEach(this.items, (r: Recording) => {
          ListItem() {
            this.row(r)
          }
        }, (r: Recording) => r.path)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 28, right: 28 })
      .backgroundColor(Color.White)
      .scrollBar(BarState.Off)
    }
  }
}