import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { frontendURL } from '../../../helper/URLHelper';
import { GLINT_REACH_MODULES } from './constants';

import GlintReachRouteView from './pages/GlintReachRouteView.vue';
import GlintReachOverviewPage from './pages/GlintReachOverviewPage.vue';
import GlintReachModulePage from './pages/GlintReachModulePage.vue';

export const meta = {
  featureFlag: FEATURE_FLAGS.GLINT_REACH,
  permissions: ['administrator'],
};

const moduleRoutes = GLINT_REACH_MODULES.map(module => ({
  path: module.path,
  name: module.routeName,
  meta,
  component:
    module.key === 'overview' ? GlintReachOverviewPage : GlintReachModulePage,
  props: module.key === 'overview' ? {} : { moduleKey: module.key },
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
    ],
  },
];
