"use client";

import { useEffect, useRef, useState } from "react";
import { supabase } from "@/lib/supabase";
import { api } from "@/lib/api";
import { Suspense } from "react";

/**
 * Supabase access_token으로 백엔드 verifyLogin 호출 후 유저 정보를 localStorage에 저장.
 * verifyLogin 실패 시 viewer fallback.
 */
async function storeUser(session: { user: { email?: string; id: string }; access_token: string }) {
  let role = "viewer";
  try {
    const loginRes = await api.verifyLogin(session.access_token);
    role = loginRes.user.role;
  } catch (err) {
    console.warn("[auth/callback] verifyLogin failed, falling back to viewer:", err);
  }
  const userData = { email: session.user.email, role, id: session.user.id };
  console.log("[auth/callback] Storing user:", userData);
  localStorage.setItem("portfiq_admin_user", JSON.stringify(userData));
}

function CallbackHandler() {
  const [error, setError] = useState("");
  const handled = useRef(false);

  useEffect(() => {
    if (handled.current) return;
    handled.current = true;

    const handleCallback = async () => {
      try {
        const url = new URL(window.location.href);
        const code = url.searchParams.get("code");
        console.log("[auth/callback] code param:", code ? "present" : "missing");

        // 1) PKCE flow
        if (code) {
          console.log("[auth/callback] Exchanging code for session...");
          const { data, error: exchangeError } =
            await supabase.auth.exchangeCodeForSession(code);

          if (exchangeError) {
            console.error("[auth/callback] Exchange error:", exchangeError.message);
            throw new Error(exchangeError.message);
          }

          if (data.session) {
            console.log("[auth/callback] Session obtained, storing user...");
            await storeUser(data.session);
            console.log("[auth/callback] Redirecting to / via full page reload...");
            window.location.href = "/";
            return;
          }
          console.warn("[auth/callback] Exchange succeeded but no session in response");
        }

        // 2) 이미 세션이 있는 경우
        console.log("[auth/callback] Checking existing session...");
        const { data } = await supabase.auth.getSession();
        if (data.session) {
          console.log("[auth/callback] Existing session found, storing user...");
          await storeUser(data.session);
          window.location.href = "/";
          return;
        }

        // 3) 세션 없음
        console.error("[auth/callback] No session found at all");
        setError("Sign-in failed. No session found.");
      } catch (err) {
        console.error("[auth/callback] Error:", err);
        setError(err instanceof Error ? err.message : "Authentication failed");
      }
    };

    handleCallback();
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  if (error) {
    return (
      <div className="min-h-screen bg-background flex items-center justify-center p-4">
        <div className="w-full max-w-sm text-center space-y-4">
          <div className="bg-negative/10 border border-negative/30 rounded-btn px-4 py-3 text-sm text-negative">
            {error}
          </div>
          <button
            onClick={() => { window.location.href = "/login"; }}
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
