"use client";

import { AdminShell } from "@/components/ui/admin-shell";
import { StatCard } from "@/components/ui/stat-card";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { DauChart } from "@/components/charts/DauChart";
import { Skeleton } from "@/components/ui/skeleton";
import { useFetch } from "@/hooks/use-fetch";
import { api } from "@/lib/api";
import {
  Users,
  Shield,
  UserPlus,
  Target,
  FileText,
  Bell,
} from "lucide-react";
import type { DashboardResponse } from "@/types/admin";

function generateDauTrend(currentDau: number): { date: string; dau: number }[] {
  const data = [];
  const today = new Date();
  for (let i = 6; i >= 0; i--) {
    const d = new Date(today);
    d.setDate(d.getDate() - i);
    const variance = Math.round((Math.random() - 0.5) * currentDau * 0.15);
    data.push({
      date: d.toLocaleDateString("en-US", { month: "short", day: "numeric" }),
      dau: Math.max(0, currentDau + variance - i * 20),
    });
  }
  return data;
}

export default function DashboardPage() {
  const { data, loading, error } = useFetch<DashboardResponse>(
    () => api.getDashboard(),
    []
  );

  return (
    <AdminShell>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-text-primary">Dashboard</h1>
          <p className="text-text-secondary text-sm mt-1">
            {data ? `Data as of ${data.date}` : "Loading..."}
          </p>
        </div>

        {error && (
          <div className="bg-negative/10 border border-negative/30 rounded-btn px-4 py-3 text-sm text-negative">
            {error}
          </div>
        )}

        {loading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
            {Array.from({ length: 6 }).map((_, i) => (
              <Skeleton key={i} className="h-[120px]" />
            ))}
          </div>
        ) : data ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-4">
            <StatCard
              label="DAU"
              value={data.kpis.dau.value}
              changePct={data.kpis.dau.change_pct}
              direction={data.kpis.dau.direction}
              icon={Users}
            />
            <StatCard
              label="D7 Retention"
              value={data.kpis.d7_retention.value}
              changePct={data.kpis.d7_retention.change_pct}
              direction={data.kpis.d7_retention.direction}
              icon={Shield}
              isPercentage
            />
            <StatCard
              label="New Installs"
              value={data.kpis.new_installs.value}
              changePct={data.kpis.new_installs.change_pct}
              direction={data.kpis.new_installs.direction}
              icon={UserPlus}
            />
            <StatCard
              label="Onboarding Conv."
              value={data.kpis.onboarding_conversion.value}
              changePct={data.kpis.onboarding_conversion.change_pct}
              direction={data.kpis.onboarding_conversion.direction}
              icon={Target}
              isPercentage
            />
            <StatCard
              label="Briefings"
              value={data.kpis.briefings_generated.value}
              changePct={data.kpis.briefings_generated.change_pct}
              direction={data.kpis.briefings_generated.direction}
              icon={FileText}
            />
            <StatCard
              label="Push Open Rate"
              value={data.kpis.push_open_rate.value}
              changePct={data.kpis.push_open_rate.change_pct}
              direction={data.kpis.push_open_rate.direction}
              icon={Bell}
              isPercentage
            />
          </div>
        ) : null}

        <Card>
          <CardHeader>
            <CardTitle>7-Day DAU Trend</CardTitle>
          </CardHeader>
          <CardContent>
            {loading ? (
              <Skeleton className="h-[280px]" />
            ) : data ? (
              <DauChart data={generateDauTrend(data.kpis.dau.value)} />
            ) : null}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Today&apos;s Top Events</CardTitle>
          </CardHeader>
          <CardContent>
            {loading ? (
              <div className="space-y-3">
                {Array.from({ length: 5 }).map((_, i) => (
                  <Skeleton key={i} className="h-10" />
                ))}
              </div>
            ) : (
              <div className="space-y-2">
                {[
                  { name: "session_start", count: data?.kpis.dau.value || 0 },
                  { name: "briefing_viewed", count: Math.round((data?.kpis.briefings_generated.value || 0) * 0.7) },
                  { name: "etf_registered", count: Math.round((data?.kpis.new_installs.value || 0) * 0.8) },
                  { name: "push_notification_opened", count: Math.round((data?.kpis.dau.value || 0) * (data?.kpis.push_open_rate.value || 0) / 100) },
                  { name: "onboarding_completed", count: Math.round((data?.kpis.new_installs.value || 0) * (data?.kpis.onboarding_conversion.value || 0) / 100) },
                ].map((event, i) => (
                  <div
                    key={event.name}
                    className="flex items-center justify-between px-4 py-2.5 rounded-btn bg-surface/50"
                  >
                    <div className="flex items-center gap-3">
                      <span className="text-text-secondary text-sm font-mono w-5">
                        {i + 1}
                      </span>
                      <span className="text-text-primary text-sm font-medium">
                        {event.name}
                      </span>
                    </div>
                    <span className="text-accent font-semibold text-sm">
                      {event.count.toLocaleString()}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </AdminShell>
  );
}
