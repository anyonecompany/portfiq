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
            <h1 className="text-2xl font-bold text-text-primary">푸시 알림 성과</h1>
            <p className="text-text-secondary text-sm mt-1">
              푸시 알림 지표 및 분석
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
                {r === "7d" ? "최근 7일" : "최근 30일"}
              </button>
            ))}
          </div>
        </div>

        {loading ? (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            {Array.from({ length: 4 }).map((_, i) => (
              <Skeleton key={i} className="h-[120px]" />
            ))}
          </div>
        ) : error || !data ? (
          <div className="flex flex-col items-center justify-center py-16 text-center">
            <Send className="w-12 h-12 text-text-secondary/40 mb-4" />
            <p className="text-text-secondary text-sm">
              {error || "데이터가 없습니다."}
            </p>
          </div>
        ) : (
          <>
            <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
              <StatCard
                label="전체 발송"
                value={data.summary.total_sent}
                changePct={0}
                direction="flat"
                icon={Send}
              />
              <StatCard
                label="수신 완료"
                value={data.summary.total_delivered}
                changePct={0}
                direction="flat"
                icon={CheckCircle}
              />
              <StatCard
                label="오픈"
                value={data.summary.total_opened}
                changePct={0}
                direction="flat"
                icon={MousePointerClick}
              />
              <StatCard
                label="오픈율"
                value={data.summary.overall_open_rate}
                changePct={0}
                direction="flat"
                icon={Clock}
                isPercentage
              />
            </div>

            <Card>
              <CardHeader>
                <CardTitle>일별 푸시 성과</CardTitle>
              </CardHeader>
              <CardContent>
                <PushChart data={data.daily} />
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>유형별 성과</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead>
                      <tr className="border-b border-divider">
                        <th className="text-left text-text-secondary font-medium px-4 py-3">유형</th>
                        <th className="text-right text-text-secondary font-medium px-4 py-3">발송</th>
                        <th className="text-right text-text-secondary font-medium px-4 py-3">수신</th>
                        <th className="text-right text-text-secondary font-medium px-4 py-3">오픈</th>
                        <th className="text-right text-text-secondary font-medium px-4 py-3">오픈율</th>
                        <th className="text-right text-text-secondary font-medium px-4 py-3">평균 오픈 시간</th>
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
                            {Math.round(row.avg_time_to_open_seconds / 60)}분
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </CardContent>
            </Card>
          </>
        )}
      </div>
    </AdminShell>
  );
}
