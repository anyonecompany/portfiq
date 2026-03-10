"use client";

import { cn, formatNumber, formatPercent } from "@/lib/utils";
import type { LucideIcon } from "lucide-react";
import { TrendingUp, TrendingDown, Minus } from "lucide-react";

interface StatCardProps {
  label: string;
  value: number;
  changePct: number;
  direction: "up" | "down" | "flat";
  icon: LucideIcon;
  isPercentage?: boolean;
}

export function StatCard({
  label,
  value,
  changePct,
  direction,
  icon: Icon,
  isPercentage = false,
}: StatCardProps) {
  const TrendIcon =
    direction === "up"
      ? TrendingUp
      : direction === "down"
      ? TrendingDown
      : Minus;

  const trendColor =
    direction === "up"
      ? "text-positive"
      : direction === "down"
      ? "text-negative"
      : "text-text-secondary";

  return (
    <div className="bg-card border border-divider rounded-card p-5 flex flex-col gap-3">
      <div className="flex items-center justify-between">
        <span className="text-text-secondary text-sm font-medium">{label}</span>
        <div className="w-9 h-9 rounded-btn bg-accent/10 flex items-center justify-center">
          <Icon className="w-5 h-5 text-accent" />
        </div>
      </div>
      <div className="flex items-end gap-3">
        <span className="text-3xl font-bold text-text-primary">
          {isPercentage ? formatPercent(value) : formatNumber(value)}
        </span>
        <div className={cn("flex items-center gap-1 text-sm pb-1", trendColor)}>
          <TrendIcon className="w-4 h-4" />
          <span>{changePct > 0 ? "+" : ""}{changePct.toFixed(1)}%</span>
        </div>
      </div>
    </div>
  );
}
