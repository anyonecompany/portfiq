"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";
import { Suspense } from "react";

/**
 * 세션에서 유저 정보를 localStorage에 저장.
 * 추가 네트워크 호출 없이 세션 데이터만 사용.
 */
function storeUser(session: { user: { email?: string; id: string } }) {
  localStorage.setItem(
    "portfiq_admin_user",
    JSON.stringify({ email: session.user.email, role: "viewer", id: session.user.id })
  );
}

function CallbackHandler() {
  const router = useRouter();
  const [error, setError] = useState("");
  const handled = useRef(false);

  useEffect(() => {
    if (handled.current) return;
    handled.current = true;

    let cancelled = false;

    const handleCallback = async () => {
      try {
        const url = new URL(window.location.href);
        const code = url.searchParams.get("code");

        // 1) PKCE flow
        if (code) {
          const { data, error: exchangeError } =
            await supabase.auth.exchangeCodeForSession(code);

          if (exchangeError) throw new Error(exchangeError.message);

          if (data.session) {
            storeUser(data.session);
            if (cancelled) return;
            router.replace("/");
            return;
          }
        }

        // 2) 이미 세션이 있는 경우
        const { data } = await supabase.auth.getSession();
        if (data.session) {
          storeUser(data.session);
          if (cancelled) return;
          router.replace("/");
          return;
        }

        // 3) 세션 없음
        if (!cancelled) {
          setError("Sign-in failed. No session found.");
        }
      } catch (err) {
        if (cancelled) return;
        console.error("[auth/callback] Error:", err);
        setError(err instanceof Error ? err.message : "Authentication failed");
      }
    };

    handleCallback();
    return () => { cancelled = true; };
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
