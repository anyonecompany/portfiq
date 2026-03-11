"use client";

import { useState } from "react";
import { AdminShell } from "@/components/ui/admin-shell";
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { useFetch } from "@/hooks/use-fetch";
import { api } from "@/lib/api";
import { formatDateTime } from "@/lib/utils";
import {
  Rocket,
  CheckCircle,
  XCircle,
  Clock,
  ShieldCheck,
  Loader2,
  X,
} from "lucide-react";
import type { DeployStatusResponse } from "@/types/admin";

function StatusBadge({ status }: { status: string }) {
  const styles: Record<string, string> = {
    deployed: "bg-positive/10 text-positive",
    deploying: "bg-accent/10 text-accent",
    failed: "bg-negative/10 text-negative",
    pending: "bg-yellow-500/10 text-yellow-400",
  };
  const icons: Record<string, React.ReactNode> = {
    deployed: <CheckCircle className="w-3.5 h-3.5" />,
    deploying: <Loader2 className="w-3.5 h-3.5 animate-spin" />,
    failed: <XCircle className="w-3.5 h-3.5" />,
    pending: <Clock className="w-3.5 h-3.5" />,
  };

  const labels: Record<string, string> = {
    deployed: "배포 완료",
    deploying: "배포 중",
    failed: "실패",
    pending: "대기 중",
  };

  return (
    <span
      className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium ${
        styles[status] || "bg-surface text-text-secondary"
      }`}
    >
      {icons[status]}
      {labels[status] || status}
    </span>
  );
}

function TotpModal({
  open,
  onClose,
  onSubmit,
  title,
  loading,
}: {
  open: boolean;
  onClose: () => void;
  onSubmit: (code: string) => void;
  title: string;
  loading: boolean;
}) {
  const [code, setCode] = useState("");

  if (!open) return null;

  return (
    <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
      <div className="bg-card border border-divider rounded-card p-6 w-full max-w-sm">
        <div className="flex items-center justify-between mb-4">
          <h3 className="text-lg font-semibold text-text-primary">{title}</h3>
          <button onClick={onClose} className="text-text-secondary hover:text-text-primary">
            <X className="w-5 h-5" />
          </button>
        </div>
        <div className="mb-4">
          <label className="block text-sm font-medium text-text-secondary mb-1.5">
            TOTP 코드
          </label>
          <input
            type="text"
            maxLength={6}
            value={code}
            onChange={(e) => setCode(e.target.value.replace(/\D/g, ""))}
            placeholder="000000"
            className="w-full bg-surface border border-divider rounded-btn px-3 py-2.5 text-text-primary text-center text-2xl tracking-[0.5em] font-mono focus:outline-none focus:border-accent"
            autoFocus
          />
        </div>
        <div className="flex gap-3">
          <button
            onClick={onClose}
            className="flex-1 bg-surface text-text-secondary rounded-btn px-4 py-2.5 text-sm font-medium hover:bg-surface/80"
          >
            취소
          </button>
          <button
            onClick={() => {
              onSubmit(code);
              setCode("");
            }}
            disabled={code.length !== 6 || loading}
            className="flex-1 bg-accent hover:bg-accent/90 disabled:bg-accent/50 text-white rounded-btn px-4 py-2.5 text-sm font-medium"
          >
            {loading ? "확인 중..." : "확인"}
          </button>
        </div>
      </div>
    </div>
  );
}

export default function DeployPage() {
  const [runId, setRunId] = useState("");
  const [totpAction, setTotpAction] = useState<"approve" | "execute" | null>(null);
  const [releaseId, setReleaseId] = useState("");
  const [actionLoading, setActionLoading] = useState(false);
  const [message, setMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const {
    data: deployStatus,
    loading,
    error,
    refetch,
  } = useFetch<DeployStatusResponse | null>(
    () => (runId ? api.getDeployStatus(runId) : Promise.resolve(null)),
    [runId]
  );

  const handleApprove = async (totpCode: string) => {
    setActionLoading(true);
    try {
      const res = await api.approveDeploy(releaseId, totpCode);
      setMessage({ type: "success", text: res.message });
      setTotpAction(null);
    } catch (err) {
      setMessage({ type: "error", text: err instanceof Error ? err.message : "승인 실패" });
    } finally {
      setActionLoading(false);
    }
  };

  const handleExecute = async (totpCode: string) => {
    setActionLoading(true);
    try {
      const res = await api.executeDeploy(releaseId, "production", totpCode);
      setMessage({ type: "success", text: res.message });
      setRunId(res.github_run_id);
      setTotpAction(null);
    } catch (err) {
      setMessage({ type: "error", text: err instanceof Error ? err.message : "배포 실패" });
    } finally {
      setActionLoading(false);
    }
  };

  return (
    <AdminShell>
      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold text-text-primary">배포 관리</h1>
          <p className="text-text-secondary text-sm mt-1">
            릴리즈 관리 및 배포 제어
          </p>
        </div>

        {message && (
          <div
            className={`rounded-btn px-4 py-3 text-sm ${
              message.type === "success"
                ? "bg-positive/10 border border-positive/30 text-positive"
                : "bg-negative/10 border border-negative/30 text-negative"
            }`}
          >
            {message.text}
          </div>
        )}

        {error && (
          <div className="bg-negative/10 border border-negative/30 rounded-btn px-4 py-3 text-sm text-negative">
            {error}
          </div>
        )}

        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <ShieldCheck className="w-5 h-5 text-accent" />
                릴리즈 승인
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                <input
                  type="text"
                  placeholder="릴리즈 ID (예: rel_20260310_v1.2.0)"
                  value={releaseId}
                  onChange={(e) => setReleaseId(e.target.value)}
                  className="w-full bg-surface border border-divider rounded-btn px-3 py-2.5 text-text-primary placeholder:text-text-secondary/50 focus:outline-none focus:border-accent text-sm"
                />
                <button
                  onClick={() => setTotpAction("approve")}
                  disabled={!releaseId}
                  className="w-full bg-accent hover:bg-accent/90 disabled:bg-accent/50 text-white rounded-btn px-4 py-2.5 text-sm font-medium"
                >
                  TOTP로 승인
                </button>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Rocket className="w-5 h-5 text-positive" />
                배포 실행
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                <input
                  type="text"
                  placeholder="릴리즈 ID"
                  value={releaseId}
                  onChange={(e) => setReleaseId(e.target.value)}
                  className="w-full bg-surface border border-divider rounded-btn px-3 py-2.5 text-text-primary placeholder:text-text-secondary/50 focus:outline-none focus:border-accent text-sm"
                />
                <button
                  onClick={() => setTotpAction("execute")}
                  disabled={!releaseId}
                  className="w-full bg-positive hover:bg-positive/90 disabled:bg-positive/50 text-white rounded-btn px-4 py-2.5 text-sm font-medium"
                >
                  프로덕션에 배포
                </button>
              </div>
            </CardContent>
          </Card>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>배포 상태</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex gap-3 mb-4">
              <input
                type="text"
                placeholder="GitHub Actions Run ID"
                value={runId}
                onChange={(e) => setRunId(e.target.value)}
                className="flex-1 bg-surface border border-divider rounded-btn px-3 py-2.5 text-text-primary placeholder:text-text-secondary/50 focus:outline-none focus:border-accent text-sm"
              />
              <button
                onClick={refetch}
                disabled={!runId || loading}
                className="bg-accent hover:bg-accent/90 disabled:bg-accent/50 text-white rounded-btn px-4 py-2.5 text-sm font-medium"
              >
                조회
              </button>
            </div>

            {loading && runId ? (
              <Skeleton className="h-[200px]" />
            ) : deployStatus ? (
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <div>
                    <span className="text-text-secondary text-sm">릴리즈: </span>
                    <span className="text-text-primary font-medium">{deployStatus.release_id}</span>
                    <span className="text-text-secondary text-sm ml-3">v{deployStatus.version}</span>
                  </div>
                  <StatusBadge status={deployStatus.status} />
                </div>

                <div className="text-sm text-text-secondary">
                  실행자: {deployStatus.triggered_by} | 시작: {formatDateTime(deployStatus.started_at)}
                  {deployStatus.completed_at && ` | 완료: ${formatDateTime(deployStatus.completed_at)}`}
                  {` | ${deployStatus.duration_seconds}초`}
                </div>

                {deployStatus.error_log && (
                  <div className="bg-negative/10 border border-negative/30 rounded-btn px-4 py-3 text-sm text-negative font-mono">
                    {deployStatus.error_log}
                  </div>
                )}

                <div className="space-y-2">
                  {deployStatus.steps.map((step) => (
                    <div
                      key={step.name}
                      className="flex items-center justify-between px-4 py-2.5 rounded-btn bg-surface/50"
                    >
                      <div className="flex items-center gap-3">
                        {step.status === "completed" && (
                          <CheckCircle className="w-4 h-4 text-positive" />
                        )}
                        {step.status === "in_progress" && (
                          <Loader2 className="w-4 h-4 text-accent animate-spin" />
                        )}
                        {step.status === "failed" && (
                          <XCircle className="w-4 h-4 text-negative" />
                        )}
                        {step.status === "pending" && (
                          <Clock className="w-4 h-4 text-text-secondary" />
                        )}
                        <span className="text-text-primary text-sm font-medium capitalize">
                          {step.name}
                        </span>
                      </div>
                      <span className="text-text-secondary text-sm">
                        {step.duration_seconds}초
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            ) : runId ? (
              <p className="text-text-secondary text-sm text-center py-8">
                Run ID를 입력하고 조회 버튼을 눌러주세요
              </p>
            ) : (
              <p className="text-text-secondary text-sm text-center py-8">
                GitHub Actions Run ID를 입력하면 배포 상태를 확인할 수 있습니다
              </p>
            )}
          </CardContent>
        </Card>
      </div>

      <TotpModal
        open={totpAction !== null}
        onClose={() => setTotpAction(null)}
        onSubmit={totpAction === "approve" ? handleApprove : handleExecute}
        title={totpAction === "approve" ? "릴리즈 승인" : "배포 실행"}
        loading={actionLoading}
      />
    </AdminShell>
  );
}
