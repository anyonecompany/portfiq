import type {
  DashboardResponse,
  FunnelResponse,
  RetentionResponse,
  PushResponse,
  UserStatsResponse,
  EventsResponse,
  DeployApproveResponse,
  DeployExecuteResponse,
  DeployStatusResponse,
  LoginResponse,
} from "@/types/admin";
import { getAccessToken, signOut } from "./auth";

// Use Next.js rewrite proxy to avoid CORS issues.
// In development, falls back to direct API call if proxy not configured.
const API_BASE = typeof window !== "undefined"
  ? "/api/proxy"  // Browser: use same-origin proxy (no CORS)
  : (process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000");  // SSR: direct call

async function adminFetch<T>(path: string, options?: RequestInit): Promise<T> {
  const token = await getAccessToken();

  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options?.headers as Record<string, string>),
  };

  if (token) {
    headers["Authorization"] = `Bearer ${token}`;
  }

  const res = await fetch(`${API_BASE}${path}`, {
    ...options,
    headers,
  });

  if (res.status === 401) {
    await signOut();
    throw new Error("Unauthorized");
  }

  if (!res.ok) {
    const body = await res.json().catch(() => ({ detail: `API error: ${res.status}` }));
    throw new Error(body.detail || `API error: ${res.status}`);
  }

  return res.json();
}

export const api = {
  // Auth — Supabase 토큰 검증 via backend
  verifyLogin: (accessToken: string) =>
    adminFetch<LoginResponse>("/api/v1/admin/auth/login", {
      method: "POST",
      body: JSON.stringify({ access_token: accessToken }),
    }),

  logout: () =>
    adminFetch<{ message: string }>("/api/v1/admin/auth/logout", {
      method: "POST",
    }),

  // Dashboard
  getDashboard: () => adminFetch<DashboardResponse>("/api/v1/admin/dashboard"),

  // Funnel
  getFunnel: (startDate?: string, endDate?: string) => {
    const params = new URLSearchParams();
    if (startDate) params.set("start_date", startDate);
    if (endDate) params.set("end_date", endDate);
    const qs = params.toString();
    return adminFetch<FunnelResponse>(`/api/v1/admin/funnel${qs ? `?${qs}` : ""}`);
  },

  // Retention
  getRetention: (weeks?: number) => {
    const params = new URLSearchParams();
    if (weeks) params.set("weeks", String(weeks));
    const qs = params.toString();
    return adminFetch<RetentionResponse>(`/api/v1/admin/retention${qs ? `?${qs}` : ""}`);
  },

  // Push
  getPush: (startDate?: string, endDate?: string) => {
    const params = new URLSearchParams();
    if (startDate) params.set("start_date", startDate);
    if (endDate) params.set("end_date", endDate);
    const qs = params.toString();
    return adminFetch<PushResponse>(`/api/v1/admin/push${qs ? `?${qs}` : ""}`);
  },

  // Users
  getUserStats: () => adminFetch<UserStatsResponse>("/api/v1/admin/users/stats"),

  // Events
  getEvents: (params: {
    event_name?: string;
    device_id?: string;
    start_date?: string;
    end_date?: string;
    limit?: number;
    offset?: number;
  }) => {
    const searchParams = new URLSearchParams();
    if (params.event_name) searchParams.set("event_name", params.event_name);
    if (params.device_id) searchParams.set("device_id", params.device_id);
    if (params.start_date) searchParams.set("start_date", params.start_date);
    if (params.end_date) searchParams.set("end_date", params.end_date);
    if (params.limit) searchParams.set("limit", String(params.limit));
    if (params.offset) searchParams.set("offset", String(params.offset));
    const qs = searchParams.toString();
    return adminFetch<EventsResponse>(`/api/v1/admin/events${qs ? `?${qs}` : ""}`);
  },

  // Deploy
  approveDeploy: (releaseId: string, totpCode: string) =>
    adminFetch<DeployApproveResponse>("/api/v1/admin/deploy/approve", {
      method: "POST",
      body: JSON.stringify({ release_id: releaseId, totp_code: totpCode }),
    }),

  executeDeploy: (releaseId: string, targetEnvironment: string, totpCode: string) =>
    adminFetch<DeployExecuteResponse>("/api/v1/admin/deploy/execute", {
      method: "POST",
      body: JSON.stringify({
        release_id: releaseId,
        target_environment: targetEnvironment,
        totp_code: totpCode,
      }),
    }),

  getDeployStatus: (runId: string) =>
    adminFetch<DeployStatusResponse>(`/api/v1/admin/deploy/status/${runId}`),
};
