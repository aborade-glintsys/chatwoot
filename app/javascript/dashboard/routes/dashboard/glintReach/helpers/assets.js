// Client-side pre-checks for a faster error message. The server re-checks the
// file bytes, size and dimensions and is the only authority.
export const ASSET_ACCEPT = 'image/jpeg,image/png,image/webp,image/gif';
export const ASSET_TYPES = ASSET_ACCEPT.split(',');
export const ASSET_MAX_BYTES = 10 * 1024 * 1024;
export const ASSET_MAX_ALT_TEXT = 1000;
export const MAX_ASSETS_PER_VARIANT = 10;

// Returns an i18n key for the first problem, or null.
export const precheckAssetFile = file => {
  if (!file) return 'GLINT_REACH.ASSETS.ERRORS.MISSING';
  if (!ASSET_TYPES.includes(file.type)) return 'GLINT_REACH.ASSETS.ERRORS.TYPE';
  if (file.size > ASSET_MAX_BYTES) return 'GLINT_REACH.ASSETS.ERRORS.SIZE';
  return null;
};

export const formatBytes = bytes => {
  if (bytes >= 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${Math.max(1, Math.round(bytes / 1024))} KB`;
};
