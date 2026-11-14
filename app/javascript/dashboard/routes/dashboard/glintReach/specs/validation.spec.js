import {
  isValidWebsiteUrl,
  validateBrandProfile,
  validateCampaignBrief,
  epochToDateInput,
  dateInputToIso,
} from '../helpers/validation';

// Built at runtime so the no-script-url lint rule does not flag test data.
const SCRIPT_URL = ['javascript', 'alert(1)'].join(':');

describe('GlintReach validation helpers', () => {
  describe('isValidWebsiteUrl', () => {
    it.each([
      'https://acme.example',
      'http://acme.example/path?q=1',
      '',
      undefined,
    ])('accepts %s', value => {
      expect(isValidWebsiteUrl(value)).toBe(true);
    });

    it.each([
      SCRIPT_URL,
      'ftp://acme.example',
      'acme.example',
      '/about',
      'https://user:pw@acme.example',
      'data:text/html,hi',
    ])('rejects %s', value => {
      expect(isValidWebsiteUrl(value)).toBe(false);
    });
  });

  describe('validateBrandProfile', () => {
    const valid = { name: 'Acme', preferredLanguages: [], approvedCtas: [] };

    it('passes a minimal profile', () => {
      expect(validateBrandProfile(valid)).toEqual({});
    });

    it('reports required, length, URL, language and CTA errors', () => {
      expect(
        validateBrandProfile({
          name: '  ',
          description: 'a'.repeat(5001),
          websiteUrl: SCRIPT_URL,
          preferredLanguages: ['english'],
          approvedCtas: ['a'.repeat(101)],
        })
      ).toEqual({
        name: 'REQUIRED',
        description: 'TOO_LONG',
        websiteUrl: 'INVALID_URL',
        preferredLanguages: 'INVALID',
        approvedCtas: 'TOO_LONG',
      });
    });

    it('limits the number of languages and CTAs', () => {
      const errors = validateBrandProfile({
        ...valid,
        preferredLanguages: Array.from({ length: 11 }, () => 'en'),
        approvedCtas: Array.from({ length: 21 }, (_, i) => `CTA ${i}`),
      });
      expect(errors).toEqual({
        preferredLanguages: 'TOO_MANY',
        approvedCtas: 'TOO_MANY',
      });
    });
  });

  describe('validateCampaignBrief', () => {
    const valid = { name: 'Launch', objective: 'awareness', channels: [] };

    it('passes a minimal brief', () => {
      expect(validateCampaignBrief(valid)).toEqual({});
    });

    it('requires name and objective', () => {
      expect(validateCampaignBrief({ name: '', objective: '' })).toEqual({
        name: 'REQUIRED',
        objective: 'REQUIRED',
      });
    });

    it('rejects unknown channels, long fields and inverted dates', () => {
      expect(
        validateCampaignBrief({
          ...valid,
          channels: ['myspace'],
          offer: 'a'.repeat(5001),
          desiredAction: 'a'.repeat(256),
          startsAt: '2026-11-10',
          endsAt: '2026-11-10',
        })
      ).toEqual({
        channels: 'INVALID',
        offer: 'TOO_LONG',
        desiredAction: 'TOO_LONG',
        endsAt: 'END_BEFORE_START',
      });
    });
  });

  it('converts between epoch seconds and date inputs', () => {
    expect(epochToDateInput(null)).toBe('');
    expect(epochToDateInput(Date.parse('2026-10-31T00:00:00Z') / 1000)).toBe(
      '2026-10-31'
    );
    expect(dateInputToIso('2026-10-31')).toBe('2026-10-31T00:00:00.000Z');
    expect(dateInputToIso('')).toBeNull();
  });
});
