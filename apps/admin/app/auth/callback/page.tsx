"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { supabase } from "@/lib/supabase";

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

export default function AuthCallbackPage() {
  const router = useRouter();
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;

    const verify = async (accessToken: string) => {
      try {
        const res = await backendVerify(accessToken);
        if (cancelled) return;
        localStorage.setItem("portfiq_admin_user", JSON.stringify(res.user));
        router.replace("/");
      } catch (err) {
        if (cancelled) return;
        await supabase.auth.signOut();
        setError(err instanceof Error ? err.message : "Login failed");
      }
    };

    // onAuthStateChange fires INITIAL_SESSION first, then SIGNED_IN when hash is processed
    const { data: listener } = supabase.auth.onAuthStateChange(
      async (event, session) => {
        if (cancelled) return;

        if (session) {
          await verify(session.access_token);
        } else if (event === "INITIAL_SESSION") {
          // Hash not yet processed — wait for SIGNED_IN
        } else {
          // No session and not initial — redirect to login
          if (!cancelled) router.replace("/login");
        }
      }
    );

    // Timeout: if nothing happens in 10 seconds, give up
    const timeout = setTimeout(() => {
      if (!cancelled) {
        setError("Sign-in timed out. Please try again.");
      }
    }, 10000);

    return () => {
      cancelled = true;
      clearTimeout(timeout);
      listener.subscription.unsubscribe();
    };
  }, [router]);

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
