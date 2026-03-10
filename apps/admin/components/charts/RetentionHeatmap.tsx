"use client";

import type { Cohort } from "@/types/admin";
import { cn } from "@/lib/utils";

interface RetentionHeatmapProps {
  cohorts: Cohort[];
}

function getCellColor(rate: number): string {
  if (rate >= 80) return "bg-accent/80";
  if (rate >= 60) return "bg-accent/60";
  if (rate >= 40) return "bg-accent/40";
  if (rate >= 20) return "bg-accent/20";
  if (rate > 0) return "bg-accent/10";
  return "bg-surface";
}

export function RetentionHeatmap({ cohorts }: RetentionHeatmapProps) {
  const maxWeeks = Math.max(...cohorts.map((c) => c.retention.length), 0);

  return (
    <div className="overflow-x-auto">
      <table className="w-full text-sm">
        <thead>
          <tr>
            <th className="text-left text-text-secondary font-medium px-3 py-2">
              Cohort
            </th>
            <th className="text-right text-text-secondary font-medium px-3 py-2">
              Size
            </th>
            {Array.from({ length: maxWeeks }).map((_, i) => (
              <th
                key={i}
                className="text-center text-text-secondary font-medium px-3 py-2"
              >
                W{i}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {cohorts.map((cohort) => (
            <tr key={cohort.cohort_week} className="border-t border-divider/50">
              <td className="px-3 py-2 text-text-primary font-medium whitespace-nowrap">
                {cohort.cohort_week}
              </td>
              <td className="px-3 py-2 text-text-secondary text-right">
                {cohort.cohort_size}
              </td>
              {Array.from({ length: maxWeeks }).map((_, i) => {
                const week = cohort.retention.find((r) => r.week === i);
                if (!week) {
                  return (
                    <td key={i} className="px-1 py-1">
                      <div className="w-16 h-8 rounded bg-surface/30 mx-auto" />
                    </td>
                  );
                }
                return (
                  <td key={i} className="px-1 py-1">
                    <div
                      className={cn(
                        "w-16 h-8 rounded flex items-center justify-center text-xs font-medium mx-auto",
                        getCellColor(week.rate),
                        week.rate >= 40 ? "text-white" : "text-text-secondary"
                      )}
                    >
                      {week.rate.toFixed(1)}%
                    </div>
                  </td>
                );
              })}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
