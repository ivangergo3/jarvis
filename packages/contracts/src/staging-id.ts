import {z} from 'zod';

const stagingId = z
  .string()
  .regex(/^00000000-0000-800[01]-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
export const StagingId = stagingId
  .refine((id) => id !== '00000000-0000-8000-8000-000000000000')
  .brand<'StagingId'>();
export type StagingId = z.infer<typeof StagingId>;
