// ===== Dashboard KPI =====
export interface KpiMetric {
  value: number;
  change_pct: number;
  direction: "up" | "down" | "flat";
}

export interface DashboardResponse {
  date: string;
  kpis: {
    dau: KpiMetric;
    d7_retention: KpiMetric;
    new_installs: KpiMetric;
    onboarding_conversion: KpiMetric;
    briefings_generated: KpiMetric;
    push_open_rate: KpiMetric;
  };
  generated_at: string;
}

// ===== Funnel =====
export interface FunnelStep {
  step: number;
  name: string;
  event_name: string | null;
  count: number;
  pct_of_total: number;
  drop_off_pct: number;
}

export interface FunnelResponse {
  start_date: string;
  end_date: string;
  total_users_in_range: number;
  steps: FunnelStep[];
}

// ===== Retention =====
export interface RetentionWeek {
  week: number;
  active: number;
  rate: number;
}

export interface Cohort {
  cohort_week: string;
  cohort_start: string;
  cohort_size: number;
  retention: RetentionWeek[];
}

export interface RetentionResponse {
  weeks: number;
  cohorts: Cohort[];
  generated_at: string;
}

// ===== Push =====
export interface PushTypeStat {
  push_type: string;
  sent: number;
  delivered: number;
  opened: number;
  open_rate: number;
  avg_time_to_open_seconds: number;
}

export interface PushDailyStat {
  date: string;
  sent: number;
  delivered: number;
  opened: number;
  open_rate: number;
}

export interface PushResponse {
  start_date: string;
  end_date: string;
  summary: {
    total_sent: number;
    total_delivered: number;
    total_opened: number;
    overall_open_rate: number;
  };
  by_type: PushTypeStat[];
  daily: PushDailyStat[];
}

// ===== Users =====
export interface EtfHistogramEntry {
  etf_count: number | string;
  users: number;
}

export interface PlatformBreakdown {
  platform: string;
  count: number;
  pct: number;
}

export interface TopEtf {
  ticker: string;
  name: string;
  registered_count: number;
}

export interface UserStatsResponse {
  total_installs: number;
  active_devices_7d: number;
  active_devices_30d: number;
  push_enabled_count: number;
  push_enabled_pct: number;
  etf_distribution: {
    avg_etfs_per_user: number;
    median_etfs_per_user: number;
    histogram: EtfHistogramEntry[];
  };
  platform_breakdown: PlatformBreakdown[];
  top_etfs: TopEtf[];
  generated_at: string;
}

// ===== Events =====
export interface AnalyticsEvent {
  id: string;
  device_id: string;
  event_name: string;
  properties: Record<string, unknown>;
  event_timestamp: string;
  received_at: string;
}

export interface EventsResponse {
  events: AnalyticsEvent[];
  total: number;
  limit: number;
  offset: number;
  has_more: boolean;
}

// ===== Deploy =====
export interface DeployApproval {
  role: string;
  approved: boolean;
  approved_at: string | null;
}

export interface DeployApproveResponse {
  release_id: string;
  approved_by: string;
  role: string;
  totp_verified: boolean;
  approved_at: string;
  approvals_complete: boolean;
  approvals: DeployApproval[];
  message: string;
}

export interface DeployStep {
  name: string;
  status: "completed" | "in_progress" | "failed" | "pending";
  duration_seconds: number;
}

export interface DeployStatusResponse {
  run_id: string;
  release_id: string;
  version: string;
  status: "deploying" | "deployed" | "failed";
  triggered_by: string;
  started_at: string;
  completed_at: string | null;
  duration_seconds: number;
  error_log?: string;
  steps: DeployStep[];
}

export interface DeployExecuteResponse {
  release_id: string;
  github_run_id: string;
  status: string;
  triggered_by: string;
  started_at: string;
  message: string;
}

// ===== Auth =====
export interface LoginResponse {
  token_type: string;
  expires_in: number;
  user: {
    id: number;
    email: string;
    role: string;
  };
}
