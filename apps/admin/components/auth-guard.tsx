"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter, usePathname } from "next/navigation";
import { supabase } from "@/lib/supabase";

const PUBLIC_PATHS = ["/login", "/auth/callback"];

/** Promise.race 기반 타임아웃 래퍼 */
function withTimeout<T>(promise: Promise<T>, ms: number, label: string): Promise<T> {
  return Promise.race([
    promise,
    new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error(`${label} timed out (${ms}ms)`)), ms),
    ),
  ]);
}

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [ready, setReady] = useState(false);
  const checked = useRef(false);

  const isPublic = PUBLIC_PATHS.some((p) => pathname.startsWith(p));

  useEffect(() => {
    if (isPublic) {
      setReady(true);
      return;
    }

    if (checked.current) {
      setReady(true);
      return;
    }

    let cancelled = false;

    const checkSession = async () => {
      // 1) localStorage — 즉시 통과
      const stored = localStorage.getItem("portfiq_admin_user");
      if (stored) {
        checked.current = true;
        setReady(true);
        return;
      }

      // 2) Supabase 세션 (5초 타임아웃 — 행 방지)
      try {
        const { data } = await withTimeout(
          supabase.auth.getSession(),
          5000,
          "Supabase getSession",
        );
        if (cancelled) return;

        if (!data.session) {
          router.replace("/login");
          return;
        }

        const fallbackUser = {
          email: data.session.user.email,
          role: "viewer",
          id: data.session.user.id,
        };
        localStorage.setItem("portfiq_admin_user", JSON.stringify(fallbackUser));
        checked.current = true;
        setReady(true);

        // 백엔드 role 업그레이드 (비동기, 실패 무시)
        fetch("/api/proxy/api/v1/admin/auth/login", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ access_token: data.session.access_token }),
          signal: AbortSignal.timeout(8000),
        })
          .then((res) => res.ok ? res.json() : null)
          .then((json) => {
            if (!cancelled && json?.user) {
              localStorage.setItem("portfiq_admin_user", JSON.stringify(json.user));
            }
          })
          .catch(() => {});
      } catch (err) {
        console.warn("[auth-guard] Session check failed:", err);
        if (cancelled) return;
        router.replace("/login");
      }
    };

    checkSession();

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
  // eslint-disable-next-line react-hooks/exhaustive-deps
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
