"use client";

import { useEffect, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { Suspense } from "react";

const API_BASE = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

async function backendVerify(accessToken: string) {
  const res = await fetch(`${API_BASE}/api/v1/admin/auth/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ access_token: accessToken }),
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({ detail: `Error ${res.status}` }));
    throw new Error(body.detail || `Login failed (${res.status})`);
  }
  return res.json();
}

function CallbackHandler() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;

    const handleCallback = async () => {
      try {
        // 1) PKCE flow: ?code=... 파라미터가 있으면 명시적으로 교환
        const code = searchParams.get("code");
        if (code) {
          const { data, error: exchangeError } =
            await supabase.auth.exchangeCodeForSession(code);

          if (exchangeError) {
            throw new Error(exchangeError.message);
          }

          if (data.session) {
            const res = await backendVerify(data.session.access_token);
            if (cancelled) return;
            localStorage.setItem(
              "portfiq_admin_user",
              JSON.stringify(res.user)
            );
            router.replace("/");
            return;
          }
        }

        // 2) Implicit flow: #access_token=... 해시 프래그먼트 처리
        //    Supabase SDK가 자동으로 해시를 파싱 → getSession()에 반영
        const hash = window.location.hash;
        if (hash && hash.includes("access_token")) {
          // SDK가 파싱할 시간 기다리기
          await new Promise((resolve) => setTimeout(resolve, 500));

          const { data } = await supabase.auth.getSession();
          if (data.session) {
            const res = await backendVerify(data.session.access_token);
            if (cancelled) return;
            localStorage.setItem(
              "portfiq_admin_user",
              JSON.stringify(res.user)
            );
            router.replace("/");
            return;
          }
        }

        // 3) 이미 세션이 있는 경우 (다른 탭에서 로그인 등)
        const { data } = await supabase.auth.getSession();
        if (data.session) {
          const res = await backendVerify(data.session.access_token);
          if (cancelled) return;
          localStorage.setItem(
            "portfiq_admin_user",
            JSON.stringify(res.user)
          );
          router.replace("/");
          return;
        }

        // 4) onAuthStateChange 대기 (마지막 수단)
        const { data: listener } = supabase.auth.onAuthStateChange(
          async (event, session) => {
            if (cancelled) return;
            if (session && (event === "SIGNED_IN" || event === "INITIAL_SESSION")) {
              try {
                const res = await backendVerify(session.access_token);
                if (cancelled) return;
                localStorage.setItem(
                  "portfiq_admin_user",
                  JSON.stringify(res.user)
                );
                listener.subscription.unsubscribe();
                router.replace("/");
              } catch (err) {
                if (cancelled) return;
                await supabase.auth.signOut();
                setError(
                  err instanceof Error ? err.message : "Login failed"
                );
                listener.subscription.unsubscribe();
              }
            }
          }
        );

        // 10초 타임아웃
        setTimeout(() => {
          if (!cancelled) {
            listener.subscription.unsubscribe();
            setError("Sign-in timed out. Please try again.");
          }
        }, 10000);
      } catch (err) {
        if (cancelled) return;
        await supabase.auth.signOut();
        setError(err instanceof Error ? err.message : "Authentication failed");
      }
    };

    handleCallback();

    return () => {
      cancelled = true;
    };
  }, [router, searchParams]);

  if (error) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center p-4">
        <div className="w-full max-w-sm text-center space-y-4">
          <div className="bg-negative/10 border border-negative/30 rounded-btn px-4 py-3 text-sm text-negative">
            {error}
          </div>
          <button
            onClick={() => router.replace("/login")}
            className="text-accent text-sm hover:underline"
          >
            Back to login
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-background flex items-center justify-center">
      <div className="text-center space-y-3">
        <div className="w-8 h-8 border-2 border-accent border-t-transparent rounded-full animate-spin mx-auto" />
        <p className="text-text-secondary text-sm">Completing sign-in...</p>
      </div>
    </div>
  );
}

export default function AuthCallbackPage() {
  return (
    <Suspense
      fallback={
        <div className="min-h-screen bg-background flex items-center justify-center">
          <div className="w-8 h-8 border-2 border-accent border-t-transparent rounded-full animate-spin" />
        </div>
      }
    >
      <CallbackHandler />
    </Suspense>
  );
}
