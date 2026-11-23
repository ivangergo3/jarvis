import {z} from 'zod';
import {Cursor, OwnerId, Version} from './values.js';

const token = z.string().min(1).max(2048).nullable();
export const pageHeader = {
  schemaVersion: Version,
  ownerId: OwnerId,
  highWater: Cursor,
  offset: Cursor,
  totalRecords: Cursor,
  pageToken: token,
  next: token,
};
export interface PageRange {
  highWater: string;
  offset: string;
  totalRecords: string;
  pageToken: string | null;
  next: string | null;
}
export function validPageRange(page: PageRange, length: number): boolean {
  if (
    !Cursor.safeParse(page.offset).success ||
    !Cursor.safeParse(page.totalRecords).success
  )
    return false;
  const end = BigInt(page.offset) + BigInt(length);
  const total = BigInt(page.totalRecords);
  return (
    end <= total &&
    (page.highWater !== '0' || total === 0n) &&
    (end === total) === (page.next === null) &&
    (page.offset === '0') === (page.pageToken === null) &&
    (length > 0 || total === 0n) &&
    (page.next === null || page.next !== page.pageToken)
  );
}
