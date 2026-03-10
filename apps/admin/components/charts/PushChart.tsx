"use client";

import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Legend,
} from "recharts";
import type { PushDailyStat } from "@/types/admin";

interface PushChartProps {
  data: PushDailyStat[];
}

export function PushChart({ data }: PushChartProps) {
  return (
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={data} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
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
        <Legend wrapperStyle={{ color: "#9CA3AF", fontSize: 12 }} />
        <Bar dataKey="sent" fill="#6366F1" radius={[4, 4, 0, 0]} />
        <Bar dataKey="opened" fill="#10B981" radius={[4, 4, 0, 0]} />
      </BarChart>
    </ResponsiveContainer>
  );
}
