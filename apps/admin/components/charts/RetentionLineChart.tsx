"use client";

import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";
import type { Cohort } from "@/types/admin";

interface RetentionLineChartProps {
  cohorts: Cohort[];
}

const COLORS = [
  "#6366F1",
  "#10B981",
  "#F59E0B",
  "#EF4444",
  "#8B5CF6",
  "#EC4899",
  "#14B8A6",
  "#F97316",
];

export function RetentionLineChart({ cohorts }: RetentionLineChartProps) {
  // Transform cohorts into chart-friendly format
  const maxWeeks = Math.max(...cohorts.map((c) => c.retention.length), 0);
  const data = Array.from({ length: maxWeeks }).map((_, weekIdx) => {
    const point: Record<string, number | string> = { week: `W${weekIdx}` };
    cohorts.forEach((cohort) => {
      const r = cohort.retention.find((rt) => rt.week === weekIdx);
      if (r) point[cohort.cohort_week] = r.rate;
    });
    return point;
  });

  // Show at most 4 cohorts to avoid clutter
  const visibleCohorts = cohorts.slice(0, 4);

  return (
    <ResponsiveContainer width="100%" height={300}>
      <LineChart data={data} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#2D2F3A" />
        <XAxis
          dataKey="week"
          tick={{ fill: "#9CA3AF", fontSize: 12 }}
          axisLine={{ stroke: "#2D2F3A" }}
          tickLine={false}
        />
        <YAxis
          tick={{ fill: "#9CA3AF", fontSize: 12 }}
          axisLine={{ stroke: "#2D2F3A" }}
          tickLine={false}
          domain={[0, 100]}
          tickFormatter={(v) => `${v}%`}
        />
        <Tooltip
          contentStyle={{
            backgroundColor: "#16181F",
            border: "1px solid #2D2F3A",
            borderRadius: "8px",
            color: "#F9FAFB",
          }}
          formatter={(value) => [`${Number(value).toFixed(1)}%`]}
        />
        <Legend
          wrapperStyle={{ color: "#9CA3AF", fontSize: 12 }}
        />
        {visibleCohorts.map((cohort, i) => (
          <Line
            key={cohort.cohort_week}
            type="monotone"
            dataKey={cohort.cohort_week}
            stroke={COLORS[i % COLORS.length]}
            strokeWidth={2}
            dot={{ r: 3 }}
          />
        ))}
      </LineChart>
    </ResponsiveContainer>
  );
}
