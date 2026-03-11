"use client";

import { useState, useCallback } from "react";
import { AdminShell } from "@/components/ui/admin-shell";
import { Card, CardContent } from "@/components/ui/card";
import { DataTable } from "@/components/ui/data-table";
import { useFetch } from "@/hooks/use-fetch";
import { api } from "@/lib/api";
import { formatDateTime } from "@/lib/utils";
import { Search } from "lucide-react";
import type { EventsResponse, AnalyticsEvent } from "@/types/admin";

const PAGE_SIZE = 50;

const EVENT_NAMES = [
  "전체 이벤트",
  "session_start",
  "onboarding_started",
  "onboarding_completed",
  "etf_registered",
  "briefing_viewed",
  "push_permission_granted",
  "push_permission_denied",
  "push_notification_opened",
];

export default function EventsPage() {
  const [page, setPage] = useState(1);
  const [eventFilter, setEventFilter] = useState("");
  const [deviceFilter, setDeviceFilter] = useState("");

  const { data, loading, error } = useFetch<EventsResponse>(
    () =>
      api.getEvents({
        event_name: eventFilter || undefined,
        device_id: deviceFilter || undefined,
        limit: PAGE_SIZE,
        offset: (page - 1) * PAGE_SIZE,
      }),
    [page, eventFilter, deviceFilter]
  );

  const handleEventChange = useCallback((value: string) => {
    setEventFilter(value === "전체 이벤트" ? "" : value);
    setPage(1);
  }, []);

  const columns = [
    {
      key: "event_name",
      header: "이벤트",
      render: (row: AnalyticsEvent) => (
        <span className="font-mono text-accent text-xs">{row.event_name}</span>
      ),
    },
    {
      key: "device_id",
      header: "기기 ID",
      render: (row: AnalyticsEvent) => (
        <span className="font-mono text-xs truncate max-w-[120px] block">
          {row.device_id}
        </span>
      ),
    },
    {
      key: "properties",
      header: "속성",
      render: (row: AnalyticsEvent) => (
        <span className="font-mono text-xs text-text-secondary truncate max-w-[200px] block">
          {JSON.stringify(row.properties)}
        </span>
      ),
    },
    {
      key: "event_timestamp",
      header: "시간",
      render: (row: AnalyticsEvent) => (
        <span className="text-xs whitespace-nowrap">
          {formatDateTime(row.event_timestamp)}
        </span>
      ),
    },
  ];

  return (
    <AdminShell>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-text-primary">이벤트</h1>
          <p className="text-text-secondary text-sm mt-1">원시 이벤트 탐색기</p>
        </div>

        {error && (
          <div className="bg-negative/10 border border-negative/30 rounded-btn px-4 py-3 text-sm text-negative">
            {error}
          </div>
        )}

        {/* Filters */}
        <div className="flex flex-wrap gap-3">
          <select
            value={eventFilter || "전체 이벤트"}
            onChange={(e) => handleEventChange(e.target.value)}
            className="bg-surface border border-divider rounded-btn px-3 py-2 text-sm text-text-primary focus:outline-none focus:border-accent"
          >
            {EVENT_NAMES.map((name) => (
              <option key={name} value={name}>
                {name}
              </option>
            ))}
          </select>

          <div className="relative">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-text-secondary" />
            <input
              type="text"
              placeholder="기기 ID로 검색"
              value={deviceFilter}
              onChange={(e) => {
                setDeviceFilter(e.target.value);
                setPage(1);
              }}
              className="bg-surface border border-divider rounded-btn pl-9 pr-3 py-2 text-sm text-text-primary placeholder:text-text-secondary/50 focus:outline-none focus:border-accent w-64"
            />
          </div>

          {data && (
            <span className="text-sm text-text-secondary self-center ml-auto">
              {data.total.toLocaleString()}건
            </span>
          )}
        </div>

        <Card>
          <CardContent className="p-0">
            <DataTable<AnalyticsEvent>
              columns={columns}
              data={(data?.events as AnalyticsEvent[]) || []}
              total={data?.total || 0}
              page={page}
              pageSize={PAGE_SIZE}
              onPageChange={setPage}
              isLoading={loading}
            />
          </CardContent>
        </Card>
      </div>
    </AdminShell>
  );
}
