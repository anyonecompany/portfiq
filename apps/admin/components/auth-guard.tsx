"use client";

import { useEffect, useState } from "react";
import { useRouter, usePathname } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { api } from "@/lib/api";
import type { Session } from "@supabase/supabase-js";

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const checkAuth = async () => {
      const { data } = await supabase.auth.getSession();
      const session = data.session;

      if (pathname === "/login") {
        if (session) {
          // OAuth 콜백 후 로그인 페이지에 돌아온 경우 — 백엔드 검증
          try {
            const res = await api.verifyLogin(session.access_token);
            localStorage.setItem("portfiq_admin_user", JSON.stringify(res.user));
            router.replace("/");
            return;
          } catch {
            // 화이트리스트 거부 등 — 로그인 페이지에 머무름
            await supabase.auth.signOut();
          }
        }
        setReady(true);
        return;
      }

      // 보호된 페이지
      if (!session) {
        router.replace("/login");
        return;
      }

      // 백엔드 검증 (세션 유효성 + 화이트리스트)
      try {
        const res = await api.verifyLogin(session.access_token);
        localStorage.setItem("portfiq_admin_user", JSON.stringify(res.user));
        setReady(true);
      } catch {
        await supabase.auth.signOut();
        localStorage.removeItem("portfiq_admin_user");
        router.replace("/login");
      }
    };

    checkAuth();

    const { data: listener } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        if (event === "SIGNED_OUT") {
          localStorage.removeItem("portfiq_admin_user");
          router.replace("/login");
        } else if (event === "SIGNED_IN" && session && pathname === "/login") {
          try {
            const res = await api.verifyLogin(session.access_token);
            localStorage.setItem("portfiq_admin_user", JSON.stringify(res.user));
            router.replace("/");
          } catch {
            await supabase.auth.signOut();
          }
        }
      }
    );

    return () => {
      listener.subscription.unsubscribe();
    };
  }, [pathname, router]);

  if (!ready && pathname !== "/login") {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center">
        <div className="w-8 h-8 border-2 border-accent border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return <>{children}</>;
}
