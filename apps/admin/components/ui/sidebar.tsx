"use client";

import { useState } from "react";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import {
  LayoutDashboard,
  Filter,
  RotateCcw,
  Users,
  Activity,
  Bell,
  Rocket,
  Menu,
  X,
  LogOut,
} from "lucide-react";

const navItems = [
  { href: "/", label: "대시보드", icon: LayoutDashboard },
  { href: "/funnel", label: "퍼널 분석", icon: Filter },
  { href: "/retention", label: "리텐션", icon: RotateCcw },
  { href: "/users", label: "사용자", icon: Users },
  { href: "/events", label: "이벤트", icon: Activity },
  { href: "/push", label: "푸시 알림", icon: Bell },
  { href: "/deploy", label: "배포 관리", icon: Rocket },
];

export function Sidebar() {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);

  const handleLogout = async () => {
    try {
      const { signOut } = await import("@/lib/auth");
      await signOut();
    } catch {
      localStorage.removeItem("portfiq_admin_user");
      window.location.href = "/login";
    }
  };

  const sidebarContent = (
    <div className="flex flex-col h-full">
      {/* Logo */}
      <div className="p-6 border-b border-divider">
        <Link href="/" className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-btn bg-accent flex items-center justify-center">
            <span className="text-white font-bold text-sm">P</span>
          </div>
          <span className="text-text-primary font-bold text-lg">포트픽 관리자</span>
        </Link>
      </div>

      {/* Nav */}
      <nav className="flex-1 py-4 px-3 space-y-1">
        {navItems.map((item) => {
          const isActive =
            item.href === "/"
              ? pathname === "/"
              : pathname.startsWith(item.href);
          return (
            <Link
              key={item.href}
              href={item.href}
              onClick={() => setMobileOpen(false)}
              className={cn(
                "flex items-center gap-3 px-3 py-2.5 rounded-btn text-sm font-medium transition-colors",
                isActive
                  ? "bg-accent/10 text-accent"
                  : "text-text-secondary hover:text-text-primary hover:bg-surface"
              )}
            >
              <item.icon className="w-5 h-5" />
              {item.label}
            </Link>
          );
        })}
      </nav>

      {/* Logout */}
      <div className="p-3 border-t border-divider">
        <button
          onClick={handleLogout}
          className="flex items-center gap-3 px-3 py-2.5 rounded-btn text-sm font-medium text-text-secondary hover:text-negative hover:bg-surface transition-colors w-full"
        >
          <LogOut className="w-5 h-5" />
          로그아웃
        </button>
      </div>
    </div>
  );

  return (
    <>
      {/* Mobile toggle */}
      <button
        onClick={() => setMobileOpen(!mobileOpen)}
        className="lg:hidden fixed top-4 left-4 z-50 w-10 h-10 bg-card border border-divider rounded-btn flex items-center justify-center text-text-primary"
      >
        {mobileOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
      </button>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="lg:hidden fixed inset-0 bg-black/50 z-40"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Sidebar */}
      <aside
        className={cn(
          "fixed top-0 left-0 h-screen w-64 bg-card border-r border-divider z-40 transition-transform lg:translate-x-0",
          mobileOpen ? "translate-x-0" : "-translate-x-full"
        )}
      >
        {sidebarContent}
      </aside>
    </>
  );
}
