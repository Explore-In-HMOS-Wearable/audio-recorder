import { audio } from '@kit.AudioKit';
import { fileIo } from '@kit.CoreFileKit';

const TAG: string = '[Recorder]';

const SAMPLE_RATE: number = 16000;
const CHANNELS: number = 1;
const BITS_PER_SAMPLE: number = 16;

const STREAM_INFO: audio.AudioStreamInfo = {
  samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
  channels: audio.AudioChannel.CHANNEL_1,
  sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
  encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
};

/**
 * Captures microphone audio and writes it to a .wav file.
 *
 * A WAV file is a 44-byte header followed by raw PCM. The header stores the
 * total size, which is only known once recording stops — so we reserve 44
 * bytes up front, write audio after them, then seek back and fill the header.
 */
export class RecorderEngine {
  private capturer: audio.AudioCapturer | undefined = undefined;
  private file: fileIo.File | undefined = undefined;
  private dataBytes: number = 0;
  private running: boolean = false;

  /** Fired roughly every second with the elapsed recording time. */
  onTick: (seconds: number) => void = () => {};

  private tickTimer: number = -1;

  isRunning(): boolean {
    return this.running;
  }

  async start(filePath: string): Promise<void> {
    if (this.running) {
      return;
    }

    // Open the file before the microphone so no frame arrives with nowhere to go.
    this.file = fileIo.openSync(
      filePath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
    );
    this.dataBytes = 0;

    // Reserve space for the header; real values are written in stop().
    const placeholder: ArrayBuffer = new ArrayBuffer(44);
    fileIo.writeSync(this.file.fd, placeholder);

    const options: audio.AudioCapturerOptions = {
      streamInfo: STREAM_INFO,
      capturerInfo: {
        // Plain MIC, not VOICE_COMMUNICATION: we want the raw signal,
        // without the echo cancellation a call would need.
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      }
    };

    this.capturer = await audio.createAudioCapturer(options);

    this.capturer.on('audioInterrupt', (event: audio.InterruptEvent) => {
      if (event.forceType === audio.InterruptForceType.INTERRUPT_FORCE) {
        console.info(`${TAG} interrupted by system`);
      }
    });

    this.capturer.on('readData', (buffer: ArrayBuffer) => {
      if (this.file === undefined || !this.running) {
        return;
      }
      // Synchronous write keeps frames in order; async writes could interleave.
      const written: number = fileIo.writeSync(this.file.fd, buffer);
      this.dataBytes += written;
    });

    await this.capturer.start();
    this.running = true;

    this.tickTimer = setInterval(() => {
      this.onTick(this.elapsedSeconds());
    }, 1000);

    console.info(`${TAG} started: ${filePath}`);
  }

  /** Returns the number of bytes of audio captured. */
  async stop(): Promise<number> {
    if (!this.running) {
      return 0;
    }
    this.running = false;

    if (this.tickTimer !== -1) {
      clearInterval(this.tickTimer);
      this.tickTimer = -1;
    }

    if (this.capturer !== undefined) {
      this.capturer.off('readData');
      this.capturer.off('audioInterrupt');
      try {
        await this.capturer.stop();
        await this.capturer.release();
      } catch (e) {
        console.error(`${TAG} failed to close capturer`);
      }
      this.capturer = undefined;
    }

    const total: number = this.dataBytes;

    if (this.file !== undefined) {
      // Seek back to the start and write the real header.
      const header: ArrayBuffer = this.buildWavHeader(total);
      fileIo.writeSync(this.file.fd, header, { offset: 0 });
      fileIo.closeSync(this.file);
      this.file = undefined;
    }

    console.info(`${TAG} stopped — ${total} bytes of audio`);
    return total;
  }

  elapsedSeconds(): number {
    const bytesPerSecond: number = SAMPLE_RATE * CHANNELS * (BITS_PER_SAMPLE / 8);
    return Math.floor(this.dataBytes / bytesPerSecond);
  }

  /**
   * Builds the 44-byte RIFF/WAVE header.
   * Everything is little-endian, which is what `true` means in the DataView calls.
   */
  private buildWavHeader(dataSize: number): ArrayBuffer {
    const buffer: ArrayBuffer = new ArrayBuffer(44);
    const view: DataView = new DataView(buffer);
    const byteRate: number = SAMPLE_RATE * CHANNELS * (BITS_PER_SAMPLE / 8);
    const blockAlign: number = CHANNELS * (BITS_PER_SAMPLE / 8);

    // "RIFF"
    view.setUint8(0, 0x52);
    view.setUint8(1, 0x49);
    view.setUint8(2, 0x46);
    view.setUint8(3, 0x46);
    // File size minus the first 8 bytes
    view.setUint32(4, 36 + dataSize, true);
    // "WAVE"
    view.setUint8(8, 0x57);
    view.setUint8(9, 0x41);
    view.setUint8(10, 0x56);
    view.setUint8(11, 0x45);
    // "fmt "
    view.setUint8(12, 0x66);
    view.setUint8(13, 0x6D);
    view.setUint8(14, 0x74);
    view.setUint8(15, 0x20);
    view.setUint32(16, 16, true);            // fmt chunk size
    view.setUint16(20, 1, true);             // 1 = uncompressed PCM
    view.setUint16(22, CHANNELS, true);
    view.setUint32(24, SAMPLE_RATE, true);
    view.setUint32(28, byteRate, true);
    view.setUint16(32, blockAlign, true);
    view.setUint16(34, BITS_PER_SAMPLE, true);
    // "data"
    view.setUint8(36, 0x64);
    view.setUint8(37, 0x61);
    view.setUint8(38, 0x74);
    view.setUint8(39, 0x61);
    view.setUint32(40, dataSize, true);

    return buffer;
  }
}