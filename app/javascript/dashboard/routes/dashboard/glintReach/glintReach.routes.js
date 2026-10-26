import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { frontendURL } from '../../../helper/URLHelper';
import { GLINT_REACH_MODULES } from './constants';

import GlintReachRouteView from './pages/GlintReachRouteView.vue';
import GlintReachOverviewPage from './pages/GlintReachOverviewPage.vue';
import GlintReachModulePage from './pages/GlintReachModulePage.vue';
import GlintReachBrandProfilePage from './pages/GlintReachBrandProfilePage.vue';
import GlintReachCampaignsPage from './pages/GlintReachCampaignsPage.vue';
import GlintReachContentStudioPage from './pages/GlintReachContentStudioPage.vue';

export const meta = {
  featureFlag: FEATURE_FLAGS.GLINT_REACH,
  permissions: ['administrator'],
};

// Modules with a real page. Everything else renders the "coming soon" placeholder.
const MODULE_PAGES = {
  overview: GlintReachOverviewPage,
  brand_profile: GlintReachBrandProfilePage,
  campaigns: GlintReachCampaignsPage,
  content_studio: GlintReachContentStudioPage,
};

const moduleRoutes = GLINT_REACH_MODULES.map(module => ({
  path: module.path,
  name: module.routeName,
  meta,
  component: MODULE_PAGES[module.key] || GlintReachModulePage,
  props: MODULE_PAGES[module.key] ? {} : { moduleKey: module.key },
}));

export const routes = [
  {
    path: frontendURL('accounts/:accountId/glint-reach'),
    component: GlintReachRouteView,
    meta,
    children: [
      {
        path: '',
        name: 'glint_reach_index',
        meta,
        redirect: to => ({ name: 'glint_reach_overview', params: to.params }),
      },
      ...moduleRoutes,
      {
        path: 'campaigns/new',
        name: 'glint_reach_campaign_new',
        meta,
        component: GlintReachContentStudioPage,
        props: { isNew: true },
      },
      {
        path: 'content-studio/:campaignId(\\d+)',
        name: 'glint_reach_content_studio_campaign',
        meta,
        component: GlintReachContentStudioPage,
        props: route => ({ campaignId: route.params.campaignId }),
      },
    ],
  },
];
