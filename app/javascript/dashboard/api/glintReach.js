/* global axios */
import ApiClient from './ApiClient';

class GlintReachAPI extends ApiClient {
  constructor() {
    super('glint_reach', { accountScoped: true });
  }

  getShell() {
    return axios.get(`${this.url}/shell`);
  }

  getBrandProfile() {
    return axios.get(`${this.url}/brand_profile`);
  }

  saveBrandProfile(brandProfile) {
    return axios.put(`${this.url}/brand_profile`, {
      brand_profile: brandProfile,
    });
  }

  getCampaigns({ page = 1, status = '', search = '' } = {}) {
    const params = { page };
    if (status) params.status = status;
    if (search) params.search = search;
    return axios.get(`${this.url}/campaigns`, { params });
  }

  getCampaign(id) {
    return axios.get(`${this.url}/campaigns/${id}`);
  }

  createCampaign(campaign) {
    return axios.post(`${this.url}/campaigns`, { campaign });
  }

  updateCampaign(id, campaign) {
    return axios.patch(`${this.url}/campaigns/${id}`, { campaign });
  }

  getGenerations(campaignId) {
    return axios.get(`${this.url}/campaigns/${campaignId}/generations`);
  }

  getGeneration(id) {
    return axios.get(`${this.url}/generations/${id}`);
  }

  createGeneration(campaignId, generation) {
    return axios.post(`${this.url}/campaigns/${campaignId}/generations`, {
      generation,
    });
  }

  variantUrl(campaignId, contentItemId, variantId) {
    return `${this.url}/campaigns/${campaignId}/content_items/${contentItemId}/variants/${variantId}`;
  }

  updateVariant({ campaignId, contentItemId, variantId }, variant) {
    return axios.patch(this.variantUrl(campaignId, contentItemId, variantId), {
      variant,
    });
  }

  transitionVariant({ campaignId, contentItemId, variantId }, status) {
    return axios.post(
      `${this.variantUrl(campaignId, contentItemId, variantId)}/transition`,
      { status }
    );
  }
}

export default new GlintReachAPI();
