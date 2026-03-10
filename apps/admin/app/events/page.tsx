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
  "All Events",
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
    setEventFilter(value === "All Events" ? "" : value);
    setPage(1);
  }, []);

  const columns = [
    {
      key: "event_name",
      header: "Event",
      render: (row: AnalyticsEvent) => (
        <span className="font-mono text-accent text-xs">{row.event_name}</span>
      ),
    },
    {
      key: "device_id",
      header: "Device ID",
      render: (row: AnalyticsEvent) => (
        <span className="font-mono text-xs truncate max-w-[120px] block">
          {row.device_id}
        </span>
      ),
    },
    {
      key: "properties",
      header: "Properties",
      render: (row: AnalyticsEvent) => (
        <span className="font-mono text-xs text-text-secondary truncate max-w-[200px] block">
          {JSON.stringify(row.properties)}
        </span>
      ),
    },
    {
      key: "event_timestamp",
      header: "Time",
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
          <h1 className="text-2xl font-bold text-text-primary">Events</h1>
          <p className="text-text-secondary text-sm mt-1">Raw event explorer</p>
        </div>

        {error && (
          <div className="bg-negative/10 border border-negative/30 rounded-btn px-4 py-3 text-sm text-negative">
            {error}
          </div>
        )}

        {/* Filters */}
        <div className="flex flex-wrap gap-3">
          <select
            value={eventFilter || "All Events"}
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
              placeholder="Filter by Device ID"
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
              {data.total.toLocaleString()} events found
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
