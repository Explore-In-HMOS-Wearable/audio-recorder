import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG: string = '[Player]';

/** Plays back a recorded .wav file using the system AVPlayer. */
export class PlayerEngine {
  private player: media.AVPlayer | undefined = undefined;
  private currentPath: string = '';

  onFinished: () => void = () => {};
  onProgress: (seconds: number) => void = () => {};

  currentFile(): string {
    return this.currentPath;
  }

  async play(filePath: string): Promise<void> {
    await this.stop();

    this.player = await media.createAVPlayer();
    this.currentPath = filePath;

    this.player.on('audioInterrupt', (event: audio.InterruptEvent) => {
      if (event.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
        console.info(`${TAG} interrupted by system`);
        this.stop();
      }
    });

    this.player.on('audioOutputDeviceChangeWithInfo', () => {
      console.info(`${TAG} output device changed`);
    });

    this.player.on('timeUpdate', (time: number) => {
      this.onProgress(Math.floor(time / 1000));
    });

    // AVPlayer is a state machine: initialized -> prepared -> playing.
    this.player.on('stateChange', (state: string) => {
      if (state === 'initialized' && this.player !== undefined) {
        this.player.prepare();
      } else if (state === 'prepared' && this.player !== undefined) {
        this.player.play();
      } else if (state === 'completed') {
        this.currentPath = '';
        this.onFinished();
        this.stop();
      }
    });

    this.player.on('error', (err: BusinessError) => {
      console.error(`${TAG} error: ${err.message}`);
      this.stop();
    });

    const file: fileIo.File = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
    this.player.url = `fd://${file.fd}`;
  }

  async stop(): Promise<void> {
    if (this.player === undefined) {
      return;
    }
    this.currentPath = '';
    try {
      this.player.off('stateChange');
      this.player.off('timeUpdate');
      this.player.off('audioInterrupt');
      this.player.off('audioOutputDeviceChangeWithInfo');
      this.player.off('error');
      await this.player.release();
    } catch (e) {
      console.error(`${TAG} failed to release player`);
    }
    this.player = undefined;
  }
}