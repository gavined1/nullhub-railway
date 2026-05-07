import { createOrchestrationApi } from '$lib/api/orchestration';
import { encodePathSegment } from '$lib/orchestration/routes';

const BASE = '/api';

function withQuery(path: string, params: Record<string, string | number | boolean | null | undefined>): string {
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value === null || value === undefined || value === '') continue;
    search.set(key, String(value));
  }
  const query = search.toString();
  return query ? `${path}?${query}` : path;
}

function withNullTicketsQuery(
  path: string,
  params: Record<string, string | number | boolean | null | undefined>,
): string {
  const query = Object.entries(params)
    .filter(([, value]) => value !== null && value !== undefined && value !== '')
    .map(([key, value]) => {
      let encodedValue = encodeURIComponent(String(value));
      if (key === 'cursor') encodedValue = encodedValue.replace(/%3A/gi, ':');
      return `${encodeURIComponent(key)}=${encodedValue}`;
    })
    .join('&');
  return query ? `${path}?${query}` : path;
}

export { encodePathSegment };

export type LogSource = 'instance' | 'nullhub';
export type ReportOption = { value: string; label: string };
export type ReportTypeOption = ReportOption & { labels: string[] };
export type ReportRepoOption = ReportOption & { repo: string };
type InstanceStartOptions = {
  launch_mode?: string;
  verbose?: boolean;
};

type NullTicketsActionRequest = {
  method?: 'GET' | 'POST' | 'DELETE';
  path: string;
  payload?: any;
  bearer_token?: string;
};

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options
  });
  if (!res.ok) {
    const body = await res.json().catch(() => null);
    const errMsg =
      typeof body?.message === 'string'
        ? body.message
        : typeof body?.error === 'string'
          ? body.error
          : body?.error?.message || `HTTP ${res.status}`;
    throw new Error(errMsg);
  }
  if (res.status === 204) return undefined as T;
  const text = await res.text();
  if (!text) return undefined as T;
  return JSON.parse(text);
}

export const api = {
  getStatus: () => request<any>('/status'),
  getGlobalUsage: (window: '24h' | '7d' | '30d' | 'all' = '24h') =>
    request<any>(`/usage?window=${window}`),
  getComponents: () => request<any>('/components'),
  getInstances: () => request<any>('/instances'),
  getWizard: (component: string) => request<any>(`/wizard/${component}`),
  getVersions: (component: string) => request<any>(`/wizard/${component}/versions`),
  getWizardModels: (component: string, provider: string, apiKey = '') =>
    request<any>(`/wizard/${component}/models`, {
      method: 'POST',
      body: JSON.stringify({ provider, api_key: apiKey }),
    }),
  getFreePort: () => request<any>('/free-port'),
  postWizard: (component: string, data: any) =>
    request<any>(`/wizard/${component}`, { method: 'POST', body: JSON.stringify(data) }),
  startInstance: (c: string, n: string, modeOrOptions?: string | InstanceStartOptions) =>
    request<any>(`/instances/${c}/${n}/start`, {
      method: 'POST',
      body:
        typeof modeOrOptions === 'string'
          ? JSON.stringify({ launch_mode: modeOrOptions })
          : modeOrOptions
            ? JSON.stringify(modeOrOptions)
            : undefined
    }),
  stopInstance: (c: string, n: string) =>
    request<any>(`/instances/${c}/${n}/stop`, { method: 'POST' }),
  restartInstance: (c: string, n: string, options?: InstanceStartOptions) =>
    request<any>(`/instances/${c}/${n}/restart`, {
      method: 'POST',
      body: options ? JSON.stringify(options) : undefined
    }),
  deleteInstance: (c: string, n: string) =>
    request<any>(`/instances/${c}/${n}`, { method: 'DELETE' }),
  getConfig: (c: string, n: string) => request<any>(`/instances/${c}/${n}/config`),
  getProviderHealth: (c: string, n: string) =>
    request<any>(`/instances/${c}/${n}/provider-health`),
  getUsage: (c: string, n: string, window: '24h' | '7d' | '30d' | 'all' = '24h') =>
    request<any>(`/instances/${c}/${n}/usage?window=${window}`),
  getHistory: (c: string, n: string, params?: { sessionId?: string; limit?: number; offset?: number }) =>
    request<any>(
      withQuery(`/instances/${c}/${n}/history`, {
        session_id: params?.sessionId,
        limit: params?.limit,
        offset: params?.offset,
      }),
    ),
  getOnboarding: (c: string, n: string) =>
    request<any>(`/instances/${c}/${n}/onboarding`),
  getMemory: (
    c: string,
    n: string,
    params?: { stats?: boolean; key?: string; query?: string; category?: string; limit?: number },
  ) =>
    request<any>(
      withQuery(`/instances/${c}/${n}/memory`, {
        stats: params?.stats ? 1 : undefined,
        key: params?.key,
        query: params?.query,
        category: params?.category,
        limit: params?.limit,
      }),
    ),
  getSkills: (c: string, n: string, name?: string) =>
    request<any>(withQuery(`/instances/${c}/${n}/skills`, { name })),
  getSkillCatalog: (c: string, n: string) =>
    request<any>(withQuery(`/instances/${c}/${n}/skills`, { catalog: 1 })),
  installBundledSkill: (c: string, n: string, bundled: string) =>
    request<any>(`/instances/${c}/${n}/skills`, {
      method: 'POST',
      body: JSON.stringify({ bundled }),
    }),
  installSkillFromClawhub: (c: string, n: string, clawhub_slug: string) =>
    request<any>(`/instances/${c}/${n}/skills`, {
      method: 'POST',
      body: JSON.stringify({ clawhub_slug }),
    }),
  installSkillFromSource: (c: string, n: string, source: string) =>
    request<any>(`/instances/${c}/${n}/skills`, {
      method: 'POST',
      body: JSON.stringify({ source }),
    }),
  removeSkill: (c: string, n: string, skillName: string) =>
    request<any>(withQuery(`/instances/${c}/${n}/skills`, { name: skillName }), {
      method: 'DELETE',
    }),
  getIntegration: (c: string, n: string) =>
    request<any>(`/instances/${c}/${n}/integration`),
  linkIntegration: (c: string, n: string, payload: any) =>
    request<any>(`/instances/${c}/${n}/integration`, {
      method: 'POST',
      body: JSON.stringify(payload),
    }),
  nullTicketsAction: (c: string, n: string, payload: NullTicketsActionRequest) =>
    request<any>(`/instances/${c}/${n}/tickets`, {
      method: 'POST',
      body: JSON.stringify(payload),
    }),
  nullTicketsPipelines: (c: string, n: string) =>
    api.nullTicketsAction(c, n, { method: 'GET', path: '/pipelines' }),
  nullTicketsTasks: (
    c: string,
    n: string,
    params?: { pipelineId?: string; stage?: string; limit?: number; cursor?: string },
  ) =>
    api.nullTicketsAction(c, n, {
      method: 'GET',
      path: withNullTicketsQuery('/tasks', {
        pipeline_id: params?.pipelineId,
        stage: params?.stage,
        limit: params?.limit,
        cursor: params?.cursor,
      }),
    }),
  nullTicketsCreateTask: (c: string, n: string, payload: any) =>
    api.nullTicketsAction(c, n, { method: 'POST', path: '/tasks', payload }),
  nullTicketsBulkCreateTasks: (c: string, n: string, tasks: any[]) =>
    api.nullTicketsAction(c, n, { method: 'POST', path: '/tasks/bulk', payload: { tasks } }),
  nullTicketsClaimTask: (c: string, n: string, payload: any) =>
    api.nullTicketsAction(c, n, { method: 'POST', path: '/leases/claim', payload }),
  nullTicketsHeartbeatLease: (c: string, n: string, leaseId: string, bearerToken: string) =>
    api.nullTicketsAction(c, n, {
      method: 'POST',
      path: `/leases/${encodePathSegment(leaseId)}/heartbeat`,
      bearer_token: bearerToken,
    }),
  nullTicketsCreatePipeline: (c: string, n: string, payload: any) =>
    api.nullTicketsAction(c, n, { method: 'POST', path: '/pipelines', payload }),
  nullTicketsGetPipeline: (c: string, n: string, pipelineId: string) =>
    api.nullTicketsAction(c, n, { method: 'GET', path: `/pipelines/${encodePathSegment(pipelineId)}` }),
  nullTicketsGetTask: (c: string, n: string, taskId: string) =>
    api.nullTicketsAction(c, n, { method: 'GET', path: `/tasks/${encodePathSegment(taskId)}` }),
  nullTicketsAssignTask: (c: string, n: string, taskId: string, payload: any) =>
    api.nullTicketsAction(c, n, {
      method: 'POST',
      path: `/tasks/${encodePathSegment(taskId)}/assignments`,
      payload,
    }),
  nullTicketsUnassignTask: (c: string, n: string, taskId: string, agentId: string) =>
    api.nullTicketsAction(c, n, {
      method: 'DELETE',
      path: `/tasks/${encodePathSegment(taskId)}/assignments/${encodePathSegment(agentId)}`,
    }),
  nullTicketsAddDependency: (c: string, n: string, taskId: string, payload: any) =>
    api.nullTicketsAction(c, n, {
      method: 'POST',
      path: `/tasks/${encodePathSegment(taskId)}/dependencies`,
      payload,
    }),
  nullTicketsGetRunState: (c: string, n: string, taskId: string) =>
    api.nullTicketsAction(c, n, {
      method: 'GET',
      path: `/tasks/${encodePathSegment(taskId)}/run-state`,
    }),
  nullTicketsRunEvents: (
    c: string,
    n: string,
    runId: string,
    params?: { limit?: number; cursor?: string },
  ) =>
    api.nullTicketsAction(c, n, {
      method: 'GET',
      path: withNullTicketsQuery(`/runs/${encodePathSegment(runId)}/events`, {
        limit: params?.limit,
        cursor: params?.cursor,
      }),
    }),
  nullTicketsAddRunEvent: (c: string, n: string, runId: string, payload: any, bearerToken: string) =>
    api.nullTicketsAction(c, n, {
      method: 'POST',
      path: `/runs/${encodePathSegment(runId)}/events`,
      payload,
      bearer_token: bearerToken,
    }),
  nullTicketsTransitionRun: (c: string, n: string, runId: string, payload: any, bearerToken: string) =>
    api.nullTicketsAction(c, n, {
      method: 'POST',
      path: `/runs/${encodePathSegment(runId)}/transition`,
      payload,
      bearer_token: bearerToken,
    }),
  nullTicketsFailRun: (c: string, n: string, runId: string, payload: any, bearerToken: string) =>
    api.nullTicketsAction(c, n, {
      method: 'POST',
      path: `/runs/${encodePathSegment(runId)}/fail`,
      payload,
      bearer_token: bearerToken,
    }),
  nullTicketsArtifacts: (
    c: string,
    n: string,
    params?: { taskId?: string; runId?: string; limit?: number; cursor?: string },
  ) =>
    api.nullTicketsAction(c, n, {
      method: 'GET',
      path: withNullTicketsQuery('/artifacts', {
        task_id: params?.taskId,
        run_id: params?.runId,
        limit: params?.limit,
        cursor: params?.cursor,
      }),
    }),
  nullTicketsCreateArtifact: (c: string, n: string, payload: any) =>
    api.nullTicketsAction(c, n, { method: 'POST', path: '/artifacts', payload }),
  putConfig: (c: string, n: string, config: any) =>
    request<any>(`/instances/${c}/${n}/config`, { method: 'PUT', body: JSON.stringify(config) }),
  getLogs: (c: string, n: string, lines = 100, source: LogSource = 'instance') =>
    request<any>(withQuery(`/instances/${c}/${n}/logs`, { lines, source })),
  clearLogs: (c: string, n: string, source: LogSource = 'instance') =>
    request<any>(withQuery(`/instances/${c}/${n}/logs`, { source }), { method: 'DELETE' }),
  getUpdates: () => request<any>('/updates'),
  getSettings: () => request<any>('/settings'),
  putSettings: (settings: any) =>
    request<any>('/settings', { method: 'PUT', body: JSON.stringify(settings) }),

  patchConfig: (c: string, n: string, config: any) =>
    request<any>(`/instances/${c}/${n}/config`, { method: 'PATCH', body: JSON.stringify(config) }),

  patchInstance: (c: string, n: string, settings: any) =>
    request<any>(`/instances/${c}/${n}`, { method: 'PATCH', body: JSON.stringify(settings) }),

  getComponentManifest: (name: string) => request<any>(`/components/${name}/manifest`),

  refreshComponents: () => request<any>('/components/refresh', { method: 'POST' }),

  applyUpdate: (c: string, n: string) =>
    request<any>(`/instances/${c}/${n}/update`, { method: 'POST' }),

  serviceInstall: () => request<any>('/service/install', { method: 'POST' }),

  serviceUninstall: () => request<any>('/service/uninstall', { method: 'POST' }),

  serviceStatus: () => request<any>('/service/status'),

  importInstance: (component: string) =>
    request<any>(`/instances/${component}/import`, { method: 'POST' }),

  getUiModules: () => request<{ modules: Record<string, string> }>('/ui-modules'),
  getAvailableUiModules: () => request<{ name: string; repo: string; component: string }[]>('/ui-modules/available'),
  installUiModule: (name: string) => request<any>(`/ui-modules/${name}/install`, { method: 'POST' }),
  uninstallUiModule: (name: string) => request<any>(`/ui-modules/${name}`, { method: 'DELETE' }),

  validateProviders: (component: string, providers: any[]) =>
    request<any>(`/wizard/${component}/validate-providers`, {
      method: 'POST',
      body: JSON.stringify({ providers }),
    }),

  validateChannels: (component: string, channels: Record<string, any>) =>
    request<any>(`/wizard/${component}/validate-channels`, {
      method: 'POST',
      body: JSON.stringify({ channels }),
    }),

  // Saved providers
  getSavedProviders: (reveal = false) =>
    request<any>(`/providers${reveal ? '?reveal=true' : ''}`),
  createSavedProvider: (data: { provider: string; api_key: string; model?: string; base_url?: string }) =>
    request<any>('/providers', { method: 'POST', body: JSON.stringify(data) }),
  updateSavedProvider: (id: string, data: { name?: string; api_key?: string; model?: string; base_url?: string }) =>
    request<any>(`/providers/${id.replace('sp_', '')}`, { method: 'PUT', body: JSON.stringify(data) }),
  deleteSavedProvider: (id: string) =>
    request<any>(`/providers/${id.replace('sp_', '')}`, { method: 'DELETE' }),
  revalidateSavedProvider: (id: string) =>
    request<any>(`/providers/${id.replace('sp_', '')}/validate`, { method: 'POST' }),
  probeProviderModels: (baseUrl: string, apiKey: string) =>
    request<{ live_ok: boolean; reason: string; models: string[] }>('/providers/probe-models', {
      method: 'POST',
      body: JSON.stringify({ base_url: baseUrl, api_key: apiKey }),
    }),

  // Saved channels
  getSavedChannels: (reveal = false) =>
    request<any>(`/channels${reveal ? '?reveal=true' : ''}`),
  createSavedChannel: (data: { channel_type: string; account: string; config: Record<string, any> }) =>
    request<any>('/channels', { method: 'POST', body: JSON.stringify(data) }),
  updateSavedChannel: (id: string, data: { name?: string; account?: string; config?: Record<string, any> }) =>
    request<any>(`/channels/${id.replace('sc_', '')}`, { method: 'PUT', body: JSON.stringify(data) }),
  deleteSavedChannel: (id: string) =>
    request<any>(`/channels/${id.replace('sc_', '')}`, { method: 'DELETE' }),
  revalidateSavedChannel: (id: string) =>
    request<any>(`/channels/${id.replace('sc_', '')}/validate`, { method: 'POST' }),
  reportPreview: (data: { repo: string; type: string; message: string }) =>
    request<{ title: string; markdown: string; labels: string[]; repo: string }>('/report/preview', {
      method: 'POST',
      body: JSON.stringify(data),
    }),
  getReportMeta: () =>
    request<{ repos: ReportRepoOption[]; types: ReportTypeOption[] }>('/report/meta'),

  submitReport: (data: { repo: string; type: string; message: string; markdown?: string }) =>
    request<{ status: string; url?: string; title?: string; markdown?: string; labels?: string[]; repo?: string; hint?: string; error?: string; manual_url?: string }>('/report', {
      method: 'POST',
      body: JSON.stringify(data),
    }),

  ...createOrchestrationApi(request, withQuery),
};
