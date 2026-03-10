"use client";

import { AdminShell } from "@/components/ui/admin-shell";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { StatCard } from "@/components/ui/stat-card";
import { Skeleton } from "@/components/ui/skeleton";
import { useFetch } from "@/hooks/use-fetch";
import { api } from "@/lib/api";
import { Users, Smartphone, Bell, BarChart3 } from "lucide-react";
import type { UserStatsResponse } from "@/types/admin";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
} from "recharts";

const PLATFORM_COLORS = ["#6366F1", "#10B981"];

function UserStatsContent({ data }: { data: UserStatsResponse }) {
  return (
    <div className="space-y-6">
      {/* Stats Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <StatCard
          label="Total Installs"
          value={data.total_installs}
          changePct={0}
          direction="flat"
          icon={Users}
        />
        <StatCard
          label="Active (7d)"
          value={data.active_devices_7d}
          changePct={0}
          direction="flat"
          icon={Smartphone}
        />
        <StatCard
          label="Active (30d)"
          value={data.active_devices_30d}
          changePct={0}
          direction="flat"
          icon={BarChart3}
        />
        <StatCard
          label="Push Enabled"
          value={data.push_enabled_pct}
          changePct={0}
          direction="flat"
          icon={Bell}
          isPercentage
        />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* ETF Distribution */}
        <Card>
          <CardHeader>
            <CardTitle>ETF Distribution</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="text-sm text-text-secondary mb-3">
              Avg: {data.etf_distribution.avg_etfs_per_user} ETFs/user |
              Median: {data.etf_distribution.median_etfs_per_user}
            </div>
            <ResponsiveContainer width="100%" height={250}>
              <BarChart data={data.etf_distribution.histogram}>
                <CartesianGrid strokeDasharray="3 3" stroke="#2D2F3A" />
                <XAxis
                  dataKey="etf_count"
                  tick={{ fill: "#9CA3AF", fontSize: 12 }}
                  axisLine={{ stroke: "#2D2F3A" }}
                  tickLine={false}
                  label={{ value: "ETF Count", position: "insideBottom", offset: -5, fill: "#9CA3AF" }}
                />
                <YAxis
                  tick={{ fill: "#9CA3AF", fontSize: 12 }}
                  axisLine={{ stroke: "#2D2F3A" }}
                  tickLine={false}
                />
                <Tooltip
                  contentStyle={{
                    backgroundColor: "#16181F",
                    border: "1px solid #2D2F3A",
                    borderRadius: "8px",
                    color: "#F9FAFB",
                  }}
                />
                <Bar dataKey="users" fill="#6366F1" radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>

        {/* Platform Breakdown */}
        <Card>
          <CardHeader>
            <CardTitle>Platform Breakdown</CardTitle>
          </CardHeader>
          <CardContent>
            <ResponsiveContainer width="100%" height={250}>
              <PieChart>
                <Pie
                  data={data.platform_breakdown}
                  dataKey="count"
                  nameKey="platform"
                  cx="50%"
                  cy="50%"
                  outerRadius={90}
                  label={(props) =>
                    `${String(props.name || "").toUpperCase()} ${((props.percent as number) * 100).toFixed(0)}%`
                  }
                >
                  {data.platform_breakdown.map((_, i) => (
                    <Cell key={i} fill={PLATFORM_COLORS[i % PLATFORM_COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{
                    backgroundColor: "#16181F",
                    border: "1px solid #2D2F3A",
                    borderRadius: "8px",
                    color: "#F9FAFB",
                  }}
                />
              </PieChart>
            </ResponsiveContainer>
          </CardContent>
        </Card>
      </div>

      {/* Top ETFs */}
      <Card>
        <CardHeader>
          <CardTitle>Top ETFs</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-divider">
                  <th className="text-left text-text-secondary font-medium px-4 py-3">Rank</th>
                  <th className="text-left text-text-secondary font-medium px-4 py-3">Ticker</th>
                  <th className="text-left text-text-secondary font-medium px-4 py-3">Name</th>
                  <th className="text-right text-text-secondary font-medium px-4 py-3">Registered</th>
                </tr>
              </thead>
              <tbody>
                {data.top_etfs.map((etf, i) => (
                  <tr key={etf.ticker} className="border-b border-divider/50 hover:bg-surface/50">
                    <td className="px-4 py-3 text-text-secondary">{i + 1}</td>
                    <td className="px-4 py-3 text-accent font-medium">{etf.ticker}</td>
                    <td className="px-4 py-3 text-text-primary">{etf.name}</td>
                    <td className="px-4 py-3 text-text-primary text-right font-medium">
                      {etf.registered_count.toLocaleString()}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

export default function UsersPage() {
  const { data, loading, error } = useFetch<UserStatsResponse>(
    () => api.getUserStats(),
    []
  );

  return (
    <AdminShell>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-text-primary">Users</h1>
          <p className="text-text-secondary text-sm mt-1">User statistics and demographics</p>
        </div>

        {error && (
          <div className="bg-negative/10 border border-negative/30 rounded-btn px-4 py-3 text-sm text-negative">
            {error}
          </div>
        )}

        {loading ? (
          <div className="space-y-6">
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              {Array.from({ length: 4 }).map((_, i) => (
                <Skeleton key={i} className="h-[120px]" />
              ))}
            </div>
            <Skeleton className="h-[300px]" />
          </div>
        ) : data ? (
          <UserStatsContent data={data} />
        ) : null}
      </div>
    </AdminShell>
  );
}
