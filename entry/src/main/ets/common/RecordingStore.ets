import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

const TAG: string = '[Store]';

export interface Recording {
  name: string;      // file name on disk
  path: string;      // full path
  sizeBytes: number;
  createdAt: number; // parsed from the file name
}

/** Owns the recordings folder: naming, listing, deleting. */
export class RecordingStore {
  private dir: string = '';

  init(context: common.UIAbilityContext): void {
    this.dir = `${context.filesDir}/recordings`;
    if (!fileIo.accessSync(this.dir)) {
      fileIo.mkdirSync(this.dir);
    }
    console.info(`${TAG} directory: ${this.dir}`);
  }

  /** Timestamp in the name means the list sorts itself. */
  newFilePath(): string {
    return `${this.dir}/rec_${Date.now()}.wav`;
  }

  list(): Recording[] {
    if (this.dir === '') {
      return [];
    }
    const names: string[] = fileIo.listFileSync(this.dir);
    const items: Recording[] = [];

    for (let i = 0; i < names.length; i++) {
      const name: string = names[i];
      if (!name.endsWith('.wav')) {
        continue;
      }
      const path: string = `${this.dir}/${name}`;
      const stat: fileIo.Stat = fileIo.statSync(path);
      items.push({
        name: name,
        path: path,
        sizeBytes: stat.size,
        createdAt: this.timestampOf(name)
      });
    }

    // Newest first
    items.sort((a: Recording, b: Recording) => b.createdAt - a.createdAt);
    return items;
  }

  delete(path: string): void {
    try {
      fileIo.unlinkSync(path);
    } catch (e) {
      console.error(`${TAG} failed to delete: ${path}`);
    }
  }

  /** "rec_1736853120000.wav" -> 1736853120000 */
  private timestampOf(name: string): number {
    const start: number = name.indexOf('_') + 1;
    const end: number = name.lastIndexOf('.');
    const parsed: number = Number.parseInt(name.substring(start, end), 10);
    return Number.isNaN(parsed) ? 0 : parsed;
  }
}