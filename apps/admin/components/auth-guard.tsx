"use client";

import { useEffect, useState, useRef } from "react";
import { useRouter, usePathname } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { api } from "@/lib/api";

export function AuthGuard({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [ready, setReady] = useState(false);
  const pathnameRef = useRef(pathname);
  pathnameRef.current = pathname;

  useEffect(() => {
    let cancelled = false;

    const verifyAndRedirect = async (accessToken: string) => {
      try {
        const res = await api.verifyLogin(accessToken);
        if (cancelled) return;
        localStorage.setItem("portfiq_admin_user", JSON.stringify(res.user));
        if (pathnameRef.current === "/login") {
          router.replace("/");
        } else {
          setReady(true);
        }
      } catch {
        if (cancelled) return;
        await supabase.auth.signOut();
        localStorage.removeItem("portfiq_admin_user");
        if (pathnameRef.current !== "/login") {
          router.replace("/login");
        }
        setReady(true); // login 페이지 렌더링 허용
      }
    };

    const checkAuth = async () => {
      const { data } = await supabase.auth.getSession();
      const session = data.session;

      if (cancelled) return;

      if (pathname === "/login") {
        if (session) {
          await verifyAndRedirect(session.access_token);
        } else {
          setReady(true);
        }
        return;
      }

      // 보호된 페이지
      if (!session) {
        router.replace("/login");
        return;
      }

      await verifyAndRedirect(session.access_token);
    };

    checkAuth();

    const { data: listener } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        if (cancelled) return;

        if (event === "SIGNED_OUT") {
          localStorage.removeItem("portfiq_admin_user");
          router.replace("/login");
        } else if (event === "SIGNED_IN" && session) {
          // pathname 상관없이 처리 — ref로 최신값 사용
          await verifyAndRedirect(session.access_token);
        }
      }
    );

    return () => {
      cancelled = true;
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
