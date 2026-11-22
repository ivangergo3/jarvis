import {z} from 'zod';

export const Request = z.strictObject({
  version: z.literal(1),
  projectId: z.string().min(1),
  sessionId: z.string().min(1),
  text: z.string().min(1).max(64),
});
export type Request = z.infer<typeof Request>;
