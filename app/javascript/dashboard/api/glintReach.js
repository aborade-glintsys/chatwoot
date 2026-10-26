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
}

export default new GlintReachAPI();
