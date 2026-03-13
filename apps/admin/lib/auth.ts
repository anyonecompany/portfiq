import { supabase } from "./supabase";
import type { Session } from "@supabase/supabase-js";

/** 5초 타임아웃 — Supabase 세션 리프레시가 행(hang)하는 경우 방지 */
export async function getSession(): Promise<Session | null> {
  try {
    const result = await Promise.race([
      supabase.auth.getSession(),
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new Error("getSession timeout")), 5000),
      ),
    ]);
    return result.data.session;
  } catch {
    return null;
  }
}

export async function getAccessToken(): Promise<string | null> {
  const session = await getSession();
  return session?.access_token ?? null;
}

export async function signOut(): Promise<void> {
  await supabase.auth.signOut();
  localStorage.removeItem("portfiq_admin_user");
  // full page reload로 상태 완전 초기화
  if (typeof window !== "undefined") {
    window.location.replace("/login");
  }
}
