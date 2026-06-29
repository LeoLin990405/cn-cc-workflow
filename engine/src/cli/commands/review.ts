import { createHash } from 'node:crypto';

import { Command, Option } from 'clipanion';

import { renderReviewPacket, reviewPacket } from '../../domain/review-packet.js';
import { NodeFileSystem } from '../../infra/node-file-system.js';

const fs = (): NodeFileSystem => new NodeFileSystem();

const sha256 = (value: string): string => createHash('sha256').update(value).digest('hex');

const readStream = async (stream: AsyncIterable<Buffer | string>): Promise<string> => {
  let out = '';
  for await (const chunk of stream) {
    out += typeof chunk === 'string' ? chunk : chunk.toString('utf8');
  }
  return out;
};

/** `fugue review packet <file|->` — turn reviewer text into a structured packet. */
export class ReviewPacketCommand extends Command {
  static override paths = [['review', 'packet']];

  file = Option.String();
  sourceRef = Option.String('--source-ref');
  json = Option.Boolean('--json', false);

  override async execute(): Promise<number> {
    const content =
      this.file === '-'
        ? await readStream(this.context.stdin as AsyncIterable<Buffer | string>)
        : await fs().read(this.file);
    if (content === null) {
      this.context.stderr.write(`no review file ${this.file}\n`);
      return 1;
    }
    if (content.trim().length === 0) {
      this.context.stderr.write('review input is empty\n');
      return 1;
    }
    const packet = reviewPacket(content, {
      sourceRef: this.sourceRef ?? (this.file === '-' ? 'stdin' : this.file),
      sourceSha256: sha256(content),
    });
    this.context.stdout.write(
      this.json ? `${JSON.stringify(packet, null, 2)}\n` : renderReviewPacket(packet),
    );
    return 0;
  }
}
