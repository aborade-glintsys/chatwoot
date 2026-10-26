/* global axios */
import ApiClient from './ApiClient';

class GlintReachAPI extends ApiClient {
  constructor() {
    super('glint_reach', { accountScoped: true });
  }

  getShell() {
    return axios.get(`${this.url}/shell`);
  }
}

export default new GlintReachAPI();
