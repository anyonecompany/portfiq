"use client";

import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
} from "recharts";

interface DauChartProps {
  data: { date: string; dau: number }[];
}

export function DauChart({ data }: DauChartProps) {
  return (
    <ResponsiveContainer width="100%" height={280}>
      <AreaChart data={data} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
        <defs>
          <linearGradient id="dauGradient" x1="0" y1="0" x2="0" y2="1">
            <stop offset="5%" stopColor="#6366F1" stopOpacity={0.3} />
            <stop offset="95%" stopColor="#6366F1" stopOpacity={0} />
          </linearGradient>
        </defs>
        <CartesianGrid strokeDasharray="3 3" stroke="#2D2F3A" />
        <XAxis
          dataKey="date"
          tick={{ fill: "#9CA3AF", fontSize: 12 }}
          axisLine={{ stroke: "#2D2F3A" }}
          tickLine={false}
        />
        <YAxis
          tick={{ fill: "#9CA3AF", fontSize: 12 }}
          axisLine={{ stroke: "#2D2F3A" }}
          tickLine={false}
        />
        <Tooltip
          contentStyle={{
            backgroundColor: "#16181F",
            border: "1px solid #2D2F3A",
            borderRadius: "8px",
            color: "#F9FAFB",
          }}
        />
        <Area
          type="monotone"
          dataKey="dau"
          stroke="#6366F1"
          strokeWidth={2}
          fill="url(#dauGradient)"
        />
      </AreaChart>
    </ResponsiveContainer>
  );
}
