#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="llm-d"
GATEWAY_DEPLOY="llm-d-gateway-istio"
HOST_HEADER="llm-d.demo.local"
GW_SVC="llm-d-gateway-istio"

info() { echo "[INFO] $*"; }
err() { echo "[ERROR] $*" >&2; }

# Get gateway pod
GW_POD=$(kubectl get pod -n "$NAMESPACE" -l app=istio-proxy -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [[ -z "${GW_POD}" ]]; then
  # fallback by deployment name label
  GW_POD=$(kubectl get pod -n "$NAMESPACE" -l app="$GATEWAY_DEPLOY" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
fi
if [[ -z "${GW_POD}" ]]; then
  # fallback: any pod from the gateway deployment
  GW_POD=$(kubectl get pod -n "$NAMESPACE" -l gateway\.networking\.k8s\.io/gateway-name=llm-d-gateway -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
fi
if [[ -z "${GW_POD}" ]]; then
  err "Could not find gateway pod in namespace ${NAMESPACE}"; exit 1;
fi
info "Gateway pod: ${GW_POD}"

# Resolve gateway external address
GW_HOST=$(kubectl get svc -n "$NAMESPACE" "$GW_SVC" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
if [[ -z "$GW_HOST" ]]; then
  GW_HOST=$(kubectl get svc -n "$NAMESPACE" "$GW_SVC" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
fi
if [[ -z "$GW_HOST" ]]; then
  err "Gateway service has no external address"; exit 1;
fi
info "Gateway external address: $GW_HOST"
BASE_URL="http://${GW_HOST}"

# Send labeled requests with session stickiness
SESSION_A="sess-a-$(date +%s)"
SESSION_B="sess-b-$(date +%s)"

send_req() {
  local sid="$1" tid="$2";
  curl -sS -D - -o /dev/null -H "Host: ${HOST_HEADER}" -H "x-session-id: ${sid}" -H "x-test-id: ${tid}" \
    -H "content-type: application/json" \
    --max-time 60 \
    --data '{"model":"meta-llama/Llama-3.2-3B-Instruct","messages":[{"role":"user","content":"Say hello and include your pod name if you know it."}],"max_tokens":8}' \
    "$BASE_URL"/v1/chat/completions | awk -v sid="$sid" -v tid="$tid" 'BEGIN{IGNORECASE=1} tolower($0) ~ /^x-upstream-host:/ {print sid, tid, $0}'
}

info "Sending warm-up requests"
for i in {1..2}; do send_req "$SESSION_A" "warmup-a-$i"; send_req "$SESSION_B" "warmup-b-$i"; done

info "Sending measured requests"
for i in {1..5}; do send_req "$SESSION_A" "measure-a-$i"; done
for i in {1..5}; do send_req "$SESSION_B" "measure-b-$i"; done

# Fetch recent gateway logs and extract fields
info "Fetching recent gateway logs"
LOGS=$(kubectl logs -n "$NAMESPACE" "$GW_POD" --since=5m --tail=2000 || true)

# Parse JSON lines and build mapping session_id -> upstream_host set
python3 - "$SESSION_A" "$SESSION_B" <<'PY'
import json,sys
sess_a=sys.argv[1]
sess_b=sys.argv[2]
from collections import defaultdict
s=set
m=defaultdict(set)
for line in sys.stdin:
    line=line.strip()
    if not line: continue
    if not line.startswith('{'): continue
    try:
        j=json.loads(line)
    except Exception:
        continue
    sid=j.get('x_session_id') or j.get('x-session-id')
    up=j.get('upstream_host')
    tid=j.get('x_test_id') or j.get('x-test-id')
    path=j.get('path','')
    if not sid or not up: continue
    if not path.startswith('/v1'): continue
    m[sid].add(up)

for sid, ups in m.items():
    print(f"session={sid} upstreams={sorted(list(ups))}")

print("SUMMARY:")
print(f"sess_a_upstreams={sorted(list(m.get(sess_a, set())))}")
print(f"sess_b_upstreams={sorted(list(m.get(sess_b, set())))}")
PY
<<<"$LOGS"

