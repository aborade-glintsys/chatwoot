import { routes, meta } from '../glintReach.routes';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { GLINT_REACH_MODULES } from '../constants';

const collectRoutes = list =>
  list.flatMap(route => [route, ...collectRoutes(route.children || [])]);

describe('glintReach routes', () => {
  const allRoutes = collectRoutes(routes);

  it('is account scoped', () => {
    expect(routes[0].path).toBe('/app/accounts/:accountId/glint-reach');
  });

  it('requires the GlintReach flag and administrator role on every route', () => {
    expect(meta).toEqual({
      featureFlag: FEATURE_FLAGS.GLINT_REACH,
      permissions: ['administrator'],
    });
    allRoutes.forEach(route => {
      expect(route.meta).toEqual(meta);
    });
  });

  it('defines a named route for every module', () => {
    const names = allRoutes.map(route => route.name);
    GLINT_REACH_MODULES.forEach(module => {
      expect(names).toContain(module.routeName);
    });
  });

  it('redirects the index to the overview', () => {
    const index = allRoutes.find(route => route.name === 'glint_reach_index');
    expect(index.redirect({ params: { accountId: 7 } })).toEqual({
      name: 'glint_reach_overview',
      params: { accountId: 7 },
    });
  });
});
