// Computes client-side capability warnings for a content variant against its
// provider's declared Capabilities object. Publishing also enforces these on the server.
export const variantCapabilityWarnings = (variant, capabilities) => {
  if (!variant || !capabilities) return [];
  const warnings = [];
  const bodyLength = (variant.body || '').length;
  if (capabilities.maxTextLength && bodyLength > capabilities.maxTextLength) {
    warnings.push({
      key: 'TEXT_TOO_LONG',
      params: { count: bodyLength, max: capabilities.maxTextLength },
    });
  }
  const imageCount = (variant.assets || variant.assetIds || []).length;
  if (
    typeof capabilities.maxImages === 'number' &&
    imageCount > capabilities.maxImages
  ) {
    warnings.push({
      key: 'TOO_MANY_IMAGES',
      params: { count: imageCount, max: capabilities.maxImages },
    });
  }
  return warnings;
};

export const daysUntilExpiry = epochSeconds => {
  if (!epochSeconds) return null;
  const diffMs = epochSeconds * 1000 - Date.now();
  return Math.max(0, Math.ceil(diffMs / (24 * 60 * 60 * 1000)));
};
