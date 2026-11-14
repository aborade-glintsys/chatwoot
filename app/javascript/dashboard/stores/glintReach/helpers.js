import camelcaseKeys from 'camelcase-keys';
import snakecaseKeys from 'snakecase-keys';
import { parseAPIErrorResponse } from 'dashboard/store/utils/api';

// Error that keeps the server's invalid attribute names (camelCased) so forms can
// highlight the affected fields after a 422.
export class GlintReachValidationError extends Error {
  constructor(message, attributes = []) {
    super(message);
    this.name = 'GlintReachValidationError';
    this.attributes = attributes;
  }
}

export const toClient = payload =>
  payload ? camelcaseKeys(payload, { deep: true }) : payload;

export const toServer = payload => snakecaseKeys(payload, { deep: false });

export const rethrowApiError = error => {
  const attributes = (error?.response?.data?.attributes || []).map(name =>
    name.replace(/_([a-z])/g, (_, char) => char.toUpperCase())
  );
  const parsed = parseAPIErrorResponse(error);
  const message = typeof parsed === 'string' ? parsed : error?.message || '';
  throw new GlintReachValidationError(message, attributes);
};
