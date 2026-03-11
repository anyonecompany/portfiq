import { supabase } from "./supabase";
import type { Session } from "@supabase/supabase-js";

export async function getSession(): Promise<Session | null> {
  const { data } = await supabase.auth.getSession();
  return data.session;
}

export async function getAccessToken(): Promise<string | null> {
  const session = await getSession();
  return session?.access_token ?? null;
}

export async function signOut(): Promise<void> {
  await supabase.auth.signOut();
  localStorage.removeItem("portfiq_admin_user");
  window.location.href = "/login";
}
