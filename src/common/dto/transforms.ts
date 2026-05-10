import { Transform } from 'class-transformer';

export function TrimString() {
  return Transform(({ value }) =>
    typeof value === 'string' ? value.trim() : value,
  );
}

export function OptionalTrimmedString() {
  return Transform(({ value }) => {
    if (typeof value !== 'string') {
      return value;
    }

    const trimmed = value.trim();
    return trimmed === '' ? undefined : trimmed;
  });
}
