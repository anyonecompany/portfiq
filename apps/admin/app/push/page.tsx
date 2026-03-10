"use client";

import { useState } from "react";
import { AdminShell } from "@/components/ui/admin-shell";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { StatCard } from "@/components/ui/stat-card";
import { PushChart } from "@/components/charts/PushChart";
import { Skeleton } from "@/components/ui/skeleton";
import { useFetch } from "@/hooks/use-fetch";
import { api } from "@/lib/api";
import { getDateNDaysAgo, formatNumber } from "@/lib/utils";
import { Send, CheckCircle, MousePointerClick, Clock } from "lucide-react";
import type { PushResponse } from "@/types/admin";

type DateRange = "7d" | "30d";

export default function PushPage() {
  const [range, setRange] = useState<DateRange>("7d");
  const days = range === "7d" ? 7 : 30;

  const { data, loading, error } = useFetch<PushResponse>(
    () => api.getPush(getDateNDaysAgo(days), getDateNDaysAgo(0)),
    [range]
  );

  return (
    <AdminShell>
      <div className="space-y-6">
        <div className="flex items-center justify-between flex-wrap gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-primary">Push Performance</h1>
            <p className="text-text-secondary text-sm mt-1">
              Push notification metrics and analytics
            </p>
          </div>

          <div className="flex gap-2">
            {(["7d", "30d"] as DateRange[]).map((r) => (
              <button
                key={r}
                onClick={() => setRange(r)}
                className={`px-4 py-2 rounded-btn text-sm font-medium transition-colors ${
                  range === r
                    ? "bg-accent text-white"
                    : "bg-surface text-text-secondary hover:text-text-primary"
                }`}
              >
                {r === "7d" ? "Last 7 Days" : "Last 30 Days"}
              </button>
            ))}
          </div>
        </div>

        {error && (
          <div className="bg-negative/10 border border-negative/30 rounded-btn px-4 py-3 text-sm text-negative">
            {error}
          </div>
        )}

        {/* Summary Cards */}
        {loading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            {Array.from({ length: 4 }).map((_, i) => (
              <Skeleton key={i} className="h-[120px]" />
            ))}
          </div>
        ) : data ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <StatCard
              label="Total Sent"
              value={data.summary.total_sent}
              changePct={0}
              direction="flat"
              icon={Send}
            />
            <StatCard
              label="Delivered"
              value={data.summary.total_delivered}
              changePct={0}
              direction="flat"
              icon={CheckCircle}
            />
            <StatCard
              label="Opened"
              value={data.summary.total_opened}
              changePct={0}
              direction="flat"
              icon={MousePointerClick}
            />
            <StatCard
              label="Open Rate"
              value={data.summary.overall_open_rate}
              changePct={0}
              direction="flat"
              icon={Clock}
              isPercentage
            />
          </div>
        ) : null}

        {/* Daily Chart */}
        <Card>
          <CardHeader>
            <CardTitle>Daily Push Performance</CardTitle>
          </CardHeader>
          <CardContent>
            {loading ? (
              <Skeleton className="h-[300px]" />
            ) : data ? (
              <PushChart data={data.daily} />
            ) : null}
          </CardContent>
        </Card>

        {/* By Type */}
        {data && (
          <Card>
            <CardHeader>
              <CardTitle>Performance by Push Type</CardTitle>
            </CardHeader>
            <CardContent>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-divider">
                      <th className="text-left text-text-secondary font-medium px-4 py-3">Type</th>
                      <th className="text-right text-text-secondary font-medium px-4 py-3">Sent</th>
                      <th className="text-right text-text-secondary font-medium px-4 py-3">Delivered</th>
                      <th className="text-right text-text-secondary font-medium px-4 py-3">Opened</th>
                      <th className="text-right text-text-secondary font-medium px-4 py-3">Open Rate</th>
                      <th className="text-right text-text-secondary font-medium px-4 py-3">Avg. Open Time</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.by_type.map((row) => (
                      <tr key={row.push_type} className="border-b border-divider/50 hover:bg-surface/50">
                        <td className="px-4 py-3 text-accent font-medium">{row.push_type}</td>
                        <td className="px-4 py-3 text-text-primary text-right">{formatNumber(row.sent)}</td>
                        <td className="px-4 py-3 text-text-primary text-right">{formatNumber(row.delivered)}</td>
                        <td className="px-4 py-3 text-text-primary text-right">{formatNumber(row.opened)}</td>
                        <td className="px-4 py-3 text-text-primary text-right font-medium">{row.open_rate}%</td>
                        <td className="px-4 py-3 text-text-secondary text-right">
                          {Math.round(row.avg_time_to_open_seconds / 60)}m
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </CardContent>
          </Card>
        )}
      </div>
    </AdminShell>
  );
}
