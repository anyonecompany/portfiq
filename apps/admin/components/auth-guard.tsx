"use client";

import { useEffect, useState } from "react";
import { useRouter, usePathname } from "next/navigation";
import { supabase } from "@/lib/supabase";

// Auth-guard가 보호하지 않는 공개 경로
const PUBLIC_PATHS = ["/login", "/auth/callback"];

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [ready, setReady] = useState(false);

  const isPublic = PUBLIC_PATHS.some((p) => pathname.startsWith(p));

  useEffect(() => {
    // 공개 페이지는 즉시 렌더링
    if (isPublic) {
      setReady(true);
      return;
    }

    let cancelled = false;

    const checkSession = async () => {
      const { data } = await supabase.auth.getSession();
      if (cancelled) return;

      if (!data.session) {
        router.replace("/login");
        return;
      }

      // 세션 존재 — localStorage에 유저 정보가 있으면 바로 통과
      const stored = localStorage.getItem("portfiq_admin_user");
      if (stored) {
        setReady(true);
        return;
      }

      // localStorage에 없으면 백엔드 검증 (새 탭 등)
      try {
        const res = await fetch(
          `${process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000"}/api/v1/admin/auth/login`,
          {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ access_token: data.session.access_token }),
          }
        );
        if (!res.ok) throw new Error("Verification failed");
        const json = await res.json();
        if (cancelled) return;
        localStorage.setItem("portfiq_admin_user", JSON.stringify(json.user));
        setReady(true);
      } catch {
        if (cancelled) return;
        await supabase.auth.signOut();
        localStorage.removeItem("portfiq_admin_user");
        router.replace("/login");
      }
    };

    checkSession();

    // 로그아웃 감지
    const { data: listener } = supabase.auth.onAuthStateChange((event) => {
      if (event === "SIGNED_OUT" && !cancelled) {
        localStorage.removeItem("portfiq_admin_user");
        setReady(false);
        router.replace("/login");
      }
    });

    return () => {
      cancelled = true;
      listener.subscription.unsubscribe();
    };
  }, [pathname, router, isPublic]);

  if (!ready && !isPublic) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return <>{children}</>;
}
