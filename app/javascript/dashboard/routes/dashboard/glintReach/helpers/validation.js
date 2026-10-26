// Client-side checks that mirror the server validations in
// GlintReach::BrandProfile and GlintReach::Campaign. The server remains the
// source of truth; these only give earlier feedback.
export const LIMITS = {
  NAME: 255,
  TEXT: 5000,
  URL: 2048,
  LANGUAGES: 10,
  CTAS: 20,
  CTA: 100,
  DESIRED_ACTION: 255,
  CAMPAIGN_TEXT: 10000,
};

export const CHANNELS = ['facebook', 'instagram', 'linkedin', 'x', 'tiktok'];
export const OBJECTIVES = [
  'awareness',
  'engagement',
  'traffic',
  'leads',
  'sales',
];
export const LOCKED_STATUSES = ['completed', 'archived'];

export const BRAND_TEXT_FIELDS = [
  'description',
  'productsServices',
  'targetAudience',
  'geographicMarket',
  'voiceAndTone',
  'messagingGuidelines',
  'prohibitedClaims',
];

const LANGUAGE_CODE = /^[a-z]{2,3}(-[A-Za-z]{2,4})?$/;

export const isValidWebsiteUrl = value => {
  if (!value) return true;
  try {
    const url = new URL(value.trim());
    return (
      ['http:', 'https:'].includes(url.protocol) &&
      Boolean(url.hostname) &&
      !url.username &&
      !url.password
    );
  } catch {
    return false;
  }
};

// Returns { field: 'ERROR_KEY' } using keys under GLINT_REACH.VALIDATION.
export const validateBrandProfile = profile => {
  const errors = {};
  const name = (profile.name || '').trim();
  if (!name) errors.name = 'REQUIRED';
  else if (name.length > LIMITS.NAME) errors.name = 'TOO_LONG';

  BRAND_TEXT_FIELDS.forEach(field => {
    if ((profile[field] || '').length > LIMITS.TEXT) errors[field] = 'TOO_LONG';
  });

  const url = (profile.websiteUrl || '').trim();
  if (url.length > LIMITS.URL) errors.websiteUrl = 'TOO_LONG';
  else if (!isValidWebsiteUrl(url)) errors.websiteUrl = 'INVALID_URL';

  const languages = profile.preferredLanguages || [];
  if (languages.length > LIMITS.LANGUAGES)
    errors.preferredLanguages = 'TOO_MANY';
  else if (!languages.every(code => LANGUAGE_CODE.test(code)))
    errors.preferredLanguages = 'INVALID';

  const ctas = profile.approvedCtas || [];
  if (ctas.length > LIMITS.CTAS) errors.approvedCtas = 'TOO_MANY';
  else if (ctas.some(cta => cta.length > LIMITS.CTA))
    errors.approvedCtas = 'TOO_LONG';

  return errors;
};

export const validateCampaignBrief = brief => {
  const errors = {};
  const name = (brief.name || '').trim();
  if (!name) errors.name = 'REQUIRED';
  else if (name.length > LIMITS.NAME) errors.name = 'TOO_LONG';

  if (!OBJECTIVES.includes(brief.objective)) errors.objective = 'REQUIRED';

  ['offer', 'keyMessage'].forEach(field => {
    if ((brief[field] || '').length > LIMITS.TEXT) errors[field] = 'TOO_LONG';
  });
  ['targetAudience', 'brief'].forEach(field => {
    if ((brief[field] || '').length > LIMITS.CAMPAIGN_TEXT)
      errors[field] = 'TOO_LONG';
  });
  if ((brief.desiredAction || '').length > LIMITS.DESIRED_ACTION)
    errors.desiredAction = 'TOO_LONG';

  if (!(brief.channels || []).every(channel => CHANNELS.includes(channel)))
    errors.channels = 'INVALID';

  if (brief.startsAt && brief.endsAt && brief.endsAt <= brief.startsAt)
    errors.endsAt = 'END_BEFORE_START';

  return errors;
};

// Date inputs work with YYYY-MM-DD; the API returns/accepts epoch seconds / ISO.
export const epochToDateInput = epoch => {
  if (!epoch) return '';
  return new Date(epoch * 1000).toISOString().slice(0, 10);
};

export const dateInputToIso = value =>
  value ? new Date(`${value}T00:00:00Z`).toISOString() : null;
