"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
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
  const [error, setError] = useState("");
  const handled = useRef(false);

  useEffect(() => {
    // 한 번만 실행 — useRef로 중복 실행 방지
    if (handled.current) return;
    handled.current = true;

    let cancelled = false;

    const handleCallback = async () => {
      try {
        // URL에서 code 파라미터 직접 추출 (useSearchParams 의존성 제거)
        const url = new URL(window.location.href);
        const code = url.searchParams.get("code");

        // 1) PKCE flow: ?code=... 파라미터가 있으면 명시적으로 교환
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
        const hash = window.location.hash;
        if (hash && hash.includes("access_token")) {
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

        // 4) 세션이 아직 없으면 타임아웃
        if (!cancelled) {
          setError("Sign-in timed out. Please try again.");
        }
      } catch (err) {
        if (cancelled) return;
        // 에러 시 세션 정리 후 에러 표시 (signOut은 한번만)
        try { await supabase.auth.signOut(); } catch { /* ignore */ }
        setError(err instanceof Error ? err.message : "Authentication failed");
      }
    };

    handleCallback();

    return () => {
      cancelled = true;
    };
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

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
