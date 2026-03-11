"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter, usePathname } from "next/navigation";
import { supabase } from "@/lib/supabase";

// Auth-guard가 보호하지 않는 공개 경로
const PUBLIC_PATHS = ["/login", "/auth/callback"];

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [ready, setReady] = useState(false);
  const checked = useRef(false);

  const isPublic = PUBLIC_PATHS.some((p) => pathname.startsWith(p));

  useEffect(() => {
    // 공개 페이지는 즉시 렌더링
    if (isPublic) {
      setReady(true);
      return;
    }

    // 이미 검증 완료된 경우 재실행 방지 (pathname 변경 시 불필요한 재검증 차단)
    if (checked.current) {
      setReady(true);
      return;
    }

    let cancelled = false;

    const checkSession = async () => {
      // 1) localStorage에 유저 정보가 있으면 즉시 통과 (가장 빠른 경로)
      const stored = localStorage.getItem("portfiq_admin_user");
      if (stored) {
        checked.current = true;
        setReady(true);
        return;
      }

      // 2) localStorage에 없으면 Supabase 세션 확인
      try {
        const { data } = await supabase.auth.getSession();
        if (cancelled) return;

        if (!data.session) {
          router.replace("/login");
          return;
        }

        // 세션 있으면 백엔드 검증 시도
        try {
          const res = await fetch(
            "/api/proxy/api/v1/admin/auth/login",
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
          checked.current = true;
          setReady(true);
        } catch {
          if (cancelled) return;
          // 백엔드 실패 시 Supabase 유저 정보로 fallback
          const { data: recheck } = await supabase.auth.getUser();
          if (recheck.user) {
            localStorage.setItem("portfiq_admin_user", JSON.stringify({
              email: recheck.user.email,
              role: "viewer",
            }));
            checked.current = true;
            setReady(true);
          } else {
            router.replace("/login");
          }
        }
      } catch (err) {
        console.warn("[auth-guard] Session check failed:", err);
        if (cancelled) return;
        router.replace("/login");
      }
    };

    checkSession();

    // 로그아웃 감지
    const { data: listener } = supabase.auth.onAuthStateChange((event) => {
      if (event === "SIGNED_OUT" && !cancelled) {
        localStorage.removeItem("portfiq_admin_user");
        checked.current = false;
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
