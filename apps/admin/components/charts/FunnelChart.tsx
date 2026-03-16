"use client";

import type { FunnelStep } from "@/types/admin";
import { formatNumber, formatPercent } from "@/lib/utils";

interface FunnelChartProps {
  steps: FunnelStep[];
}

const stepLabels: Record<string, string> = {
  app_opened: "App Opened",
  onboarding_started: "Onboarding Started",
  etf_registered: "ETF Registered",
  aha_moment_feed_viewed: "Aha Moment",
  push_permission_granted: "Push Granted",
  onboarding_completed: "Onboarding Completed",
  day7_return: "Day 7 Return",
};

export function FunnelChart({ steps }: FunnelChartProps) {
  const maxCount = steps[0]?.count || 1;

  return (
    <div className="space-y-3">
      {steps.map((step, i) => {
        const widthPct = (step.count / maxCount) * 100;
        return (
          <div key={step.step} className="flex items-center gap-4">
            <div className="w-48 flex-shrink-0 text-right">
              <span className="text-sm text-text-secondary">
                {stepLabels[step.name] || step.name}
              </span>
            </div>
            <div className="flex-1 relative">
              <div className="h-9 bg-surface rounded-btn overflow-hidden">
                <div
                  className="h-full bg-accent/80 rounded-btn transition-all duration-500 flex items-center px-3"
                  style={{ width: `${Math.max(widthPct, 2)}%` }}
                >
                  <span className="text-xs font-medium text-white whitespace-nowrap">
                    {formatNumber(step.count)}
                  </span>
                </div>
              </div>
            </div>
            <div className="w-20 flex-shrink-0 text-right space-y-0.5">
              <div className="text-sm font-medium text-text-primary">
                {formatPercent(step.pct_of_total)}
              </div>
              {i > 0 && (
                <div className="text-xs text-negative">
                  -{formatPercent(step.drop_off_pct)}
                </div>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}
