"use client";

import { useState } from "react";
import { AdminShell } from "@/components/ui/admin-shell";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { StatCard } from "@/components/ui/stat-card";
import { RetentionHeatmap } from "@/components/charts/RetentionHeatmap";
import { RetentionLineChart } from "@/components/charts/RetentionLineChart";
import { Skeleton } from "@/components/ui/skeleton";
import { useFetch } from "@/hooks/use-fetch";
import { api } from "@/lib/api";
import { RotateCcw, TrendingDown, Calendar } from "lucide-react";
import type { RetentionResponse } from "@/types/admin";

export default function RetentionPage() {
  const [weeks, setWeeks] = useState(8);

  const { data, loading, error } = useFetch<RetentionResponse>(
    () => api.getRetention(weeks),
    [weeks]
  );

  const latestCohort = data?.cohorts[0];
  const getRetRate = (weekNum: number) => {
    if (!latestCohort) return null;
    const w = latestCohort.retention.find((r) => r.week === weekNum);
    return w?.rate ?? null;
  };

  const d1 = getRetRate(1);
  const d3 = getRetRate(3);
  const d7 = getRetRate(7);

  return (
    <AdminShell>
      <div className="space-y-6">
        <div className="flex items-center justify-between flex-wrap gap-4">
          <div>
            <h1 className="text-2xl font-bold text-text-primary">리텐션</h1>
            <p className="text-text-secondary text-sm mt-1">
              주간 코호트 리텐션 분석
            </p>
          </div>

          <div className="flex gap-2">
            {[4, 8, 12].map((w) => (
              <button
                key={w}
                onClick={() => setWeeks(w)}
                className={`px-4 py-2 rounded-btn text-sm font-medium transition-colors ${
                  weeks === w
                    ? "bg-accent text-white"
                    : "bg-surface text-text-secondary hover:text-text-primary"
                }`}
              >
                {w}주
              </button>
            ))}
          </div>
        </div>

        {error && (
          <div className="bg-negative/10 border border-negative/30 rounded-btn px-4 py-3 text-sm text-negative">
            {error}
          </div>
        )}

        {loading ? (
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            {Array.from({ length: 3 }).map((_, i) => (
              <Skeleton key={i} className="h-[120px]" />
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <StatCard
              label="1주 리텐션"
              value={d1 ?? 0}
              changePct={0}
              direction="flat"
              icon={RotateCcw}
              isPercentage
            />
            <StatCard
              label="3주 리텐션"
              value={d3 ?? 0}
              changePct={0}
              direction="flat"
              icon={TrendingDown}
              isPercentage
            />
            <StatCard
              label="7주 리텐션"
              value={d7 ?? 0}
              changePct={0}
              direction="flat"
              icon={Calendar}
              isPercentage
            />
          </div>
        )}

        <Card>
          <CardHeader>
            <CardTitle>코호트 리텐션 히트맵</CardTitle>
          </CardHeader>
          <CardContent>
            {loading ? (
              <Skeleton className="h-[300px]" />
            ) : data ? (
              <RetentionHeatmap cohorts={data.cohorts} />
            ) : null}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>리텐션 곡선</CardTitle>
          </CardHeader>
          <CardContent>
            {loading ? (
              <Skeleton className="h-[300px]" />
            ) : data ? (
              <RetentionLineChart cohorts={data.cohorts} />
            ) : null}
          </CardContent>
        </Card>
      </div>
    </AdminShell>
  );
}
