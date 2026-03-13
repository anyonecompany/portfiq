"use client";

import { Sidebar } from "./sidebar";

/**
 * AdminShell — 레이아웃 컴포넌트.
 * 인증 검사는 AuthGuard가 담당하므로 여기서는 하지 않음.
 * AuthGuard를 통과한 경우에만 이 컴포넌트가 렌더링됨.
 */
export function AdminShell({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen bg-background">
      <Sidebar />
      <main className="lg:ml-64 min-h-screen p-6 lg:p-8">
        {children}
      </main>
    </div>
  );
}
