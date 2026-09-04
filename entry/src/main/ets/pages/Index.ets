import { common } from '@kit.AbilityKit';
import { RecordingStore, Recording } from '../common/RecordingStore';
import { requestMicPermission } from '../common/Permissions';
import { RecordView } from '../view/RecordView';
import { RecordingsView } from '../view/RecordingsView';

@Entry
@Component
struct Index {
  @State items: Recording[] = [];
  @State pageIndex: number = 0;

  private store: RecordingStore = new RecordingStore();

  aboutToAppear(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.store.init(ctx);
    requestMicPermission(ctx).then(() => {
      this.refresh();
    });
  }

  private refresh(): void {
    // New array, not a mutation — ArkUI compares by reference.
    this.items = this.store.list();
  }

  build() {
    Column() {
      Text(this.pageIndex === 0 ? 'Recorder' : 'Recordings')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1C1B2E')
        .padding({ top: 12, bottom: 6 })

      Swiper() {
        RecordView({
          store: this.store,
          onSaved: () => this.refresh()
        })
        RecordingsView({
          items: $items,
          store: this.store,
          onChanged: () => this.refresh()
        })
      }
      .layoutWeight(1)
      .loop(false)
      .indicator(true)
      .onChange((index: number) => {
        this.pageIndex = index;
        if (index === 1) {
          this.refresh();
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
}