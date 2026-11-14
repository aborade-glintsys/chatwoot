import {
  addDays,
  addMonths,
  addWeeks,
  eachDayOfInterval,
  endOfMonth,
  endOfWeek,
  format,
  parseISO,
  startOfMonth,
  startOfWeek,
} from 'date-fns';
import { formatInTimeZone } from 'date-fns-tz';

// Calendar math works on calendar dates (yyyy-MM-dd strings) so it never
// depends on the browser time zone; instants are converted with an explicit
// IANA zone only when placing or labelling items.
export const VIEWS = ['month', 'week', 'day'];
const DATE = 'yyyy-MM-dd';
const WEEK = { weekStartsOn: 1 };

const toDate = value => parseISO(value);
const toKey = date => format(date, DATE);

export const browserTimezone = () =>
  Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC';

export const timezoneOptions = current => {
  const zones =
    typeof Intl.supportedValuesOf === 'function'
      ? Intl.supportedValuesOf('timeZone')
      : ['UTC'];
  return [...new Set(['UTC', current, ...zones].filter(Boolean))];
};

export const todayIn = timezone => formatInTimeZone(new Date(), timezone, DATE);

export const dayKeyIn = (epochSeconds, timezone) =>
  formatInTimeZone(new Date(epochSeconds * 1000), timezone, DATE);

export const timeIn = (epochSeconds, timezone) =>
  formatInTimeZone(new Date(epochSeconds * 1000), timezone, 'HH:mm');

export const formatInstant = (epochSeconds, timezone) =>
  formatInTimeZone(
    new Date(epochSeconds * 1000),
    timezone,
    'EEE d MMM yyyy, HH:mm zzz'
  );

// Days shown for a view, as yyyy-MM-dd keys. Month views cover whole weeks.
export const daysFor = (view, anchor) => {
  const date = toDate(anchor);
  if (view === 'day') return [toKey(date)];
  if (view === 'week') {
    return eachDayOfInterval({
      start: startOfWeek(date, WEEK),
      end: endOfWeek(date, WEEK),
    }).map(toKey);
  }
  return eachDayOfInterval({
    start: startOfWeek(startOfMonth(date), WEEK),
    end: endOfWeek(endOfMonth(date), WEEK),
  }).map(toKey);
};

export const rangeFor = (view, anchor) => {
  const days = daysFor(view, anchor);
  return { from: days[0], to: days[days.length - 1] };
};

export const shiftAnchor = (view, anchor, direction) => {
  const date = toDate(anchor);
  if (view === 'month') return toKey(addMonths(date, direction));
  if (view === 'week') return toKey(addWeeks(date, direction));
  return toKey(addDays(date, direction));
};

export const isSameMonth = (dayKey, anchor) =>
  dayKey.slice(0, 7) === anchor.slice(0, 7);

export const titleFor = (view, anchor) => {
  const date = toDate(anchor);
  if (view === 'month') return format(date, 'MMMM yyyy');
  if (view === 'week') {
    const { from, to } = rangeFor('week', anchor);
    return `${format(toDate(from), 'd MMM')} – ${format(toDate(to), 'd MMM yyyy')}`;
  }
  return format(date, 'EEEE d MMMM yyyy');
};

// Groups calendar items (with scheduledAt epoch seconds) by local day key.
export const groupByDay = (items, timezone) =>
  items.reduce((groups, item) => {
    const key = dayKeyIn(item.scheduledAt, timezone);
    (groups[key] ||= []).push(item);
    return groups;
  }, {});
