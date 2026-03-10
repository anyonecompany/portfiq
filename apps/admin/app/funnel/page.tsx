"use client";

import { useState } from "react";
import { AdminShell } from "@/components/ui/admin-shell";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { FunnelChart } from "@/components/charts/FunnelChart";
import { Skeleton } from "@/components/ui/skeleton";
import { useFetch } from "@/hooks/use-fetch";
import { api } from "@/lib/api";
import { getDateNDaysAgo } from "@/lib/utils";
import type { FunnelResponse } from "@/types/admin";

type DateRange = "7d" | "30d";

export default function FunnelPage() {
  const [range, setRange] = useState<DateRange>("7d");
  const days = range === "7d" ? 7 : 30;

  const { data, loading, error } = useFetch<FunnelResponse>(
    () => api.getFunnel(getDateNDaysAgo(days), getDateNDaysAgo(0)),
    [range]
  );

  return (
    <AdminShell>
      <div className="space-y-6">
        <div className="flex items-center justify-between flex-wrap gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-primary">Funnel Analysis</h1>
            <p className="text-text-secondary text-sm mt-1">
              Onboarding funnel conversion rates
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

        <Card>
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle>7-Step Onboarding Funnel</CardTitle>
              {data && (
                <span className="text-sm text-text-secondary">
                  {data.total_users_in_range.toLocaleString()} users ({data.start_date} ~ {data.end_date})
                </span>
              )}
            </div>
          </CardHeader>
          <CardContent>
            {loading ? (
              <div className="space-y-3">
                {Array.from({ length: 7 }).map((_, i) => (
                  <Skeleton key={i} className="h-9" />
                ))}
              </div>
            ) : data ? (
              <FunnelChart steps={data.steps} />
            ) : null}
          </CardContent>
        </Card>

        {/* Summary Cards */}
        {data && (
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <Card>
              <CardContent className="text-center py-4">
                <div className="text-3xl font-bold text-accent">
                  {data.steps[data.steps.length - 1]?.pct_of_total.toFixed(1)}%
                </div>
                <div className="text-sm text-text-secondary mt-1">
                  Overall Conversion (Install to D2 Return)
                </div>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="text-center py-4">
                <div className="text-3xl font-bold text-positive">
                  {data.steps.find((s) => s.name === "onboarding_completed")?.pct_of_total.toFixed(1)}%
                </div>
                <div className="text-sm text-text-secondary mt-1">
                  Onboarding Completion Rate
                </div>
              </CardContent>
            </Card>
            <Card>
              <CardContent className="text-center py-4">
                <div className="text-3xl font-bold text-negative">
                  {Math.max(...data.steps.map((s) => s.drop_off_pct)).toFixed(1)}%
                </div>
                <div className="text-sm text-text-secondary mt-1">
                  Biggest Drop-off
                </div>
              </CardContent>
            </Card>
          </div>
        )}
      </div>
    </AdminShell>
  );
}
