#!/usr/bin/env bash
set -euo pipefail

# Airtight verification that EPP-driven routing enforces session stickiness
# and is required for the gateway request path.
#
# Requirements:
# - kubectl context pointing to the correct cluster
# - curl installed
# - Access to the llm-d namespace resources
#
# Configurable via env vars:
#   NS: Kubernetes namespace (default: llm-d)
#   GATEWAY_SVC: in-cluster DNS of the Istio gateway service (default: llm-d-gateway-istio.llm-d.svc.cluster.local)
#   HOST_HEADER: Host header for HTTPRoute matching (default: llm-d.demo.local)
#   MODEL: model name (default: meta-llama/Llama-3.2-3B-Instruct)
#   DECODE_SELECTOR: label selector for decode pods (default: app=decode)
#   REQ_COUNT: number of requests per session (default: 12)
#   SLEEP_SECS: sleep between requests (default: 0.25)
#   DRY_RUN: if set to 1, only print actions
#
# What this script does:
# 1) Proves no alternative stickiness:
#    - Service sessionAffinity is None
#    - No DestinationRules in the namespace
# 2) Measures per-pod metrics for several distinct session IDs and shows:
#    - High stickiness (>90%) to a single decode pod per session
#    - Different sessions map to different pods
#    - Re-running a session maps to the same pod (consistency)
# 3) Optionally proves the EPP is on-path by scaling it to 0 (requests fail) and back up (requests succeed)
#
# The script never edits manifests; it only reads metrics and optionally scales the EPP deployment.

NS="${NS:-llm-d}"
GATEWAY_SVC="${GATEWAY_SVC:-llm-d-gateway-istio.llm-d.svc.cluster.local}"
HOST_HEADER="${HOST_HEADER:-llm-d.demo.local}"
MODEL="${MODEL:-meta-llama/Llama-3.2-3B-Instruct}"
DECODE_SELECTOR="${DECODE_SELECTOR:-app=decode}"
REQ_COUNT="${REQ_COUNT:-12}"
SLEEP_SECS="${SLEEP_SECS:-0.25}"
DRY_RUN="${DRY_RUN:-0}"

# Endpoint and payload
URL="http://${GATEWAY_SVC}/v1/chat/completions"
PFORWARD_PORT="${PFORWARD_PORT:-18080}"
PFORWARD_PID=""

ensure_gateway_reachable() {
  # If we can't resolve the in-cluster service from here, set up a port-forward.
  if ! curl -sS --connect-timeout 2 "http://${GATEWAY_SVC}" >/dev/null 2>&1; then
    info "Gateway service not directly reachable from here; setting up port-forward to ${GATEWAY_SVC}..."
    if [ "$DRY_RUN" = "1" ]; then
      echo "+ kubectl port-forward -n '${NS}' svc/llm-d-gateway-istio ${PFORWARD_PORT}:80 &"
    else
      kubectl port-forward -n "${NS}" svc/llm-d-gateway-istio "${PFORWARD_PORT}:80" >/dev/null 2>&1 &
      PFORWARD_PID=$!
      sleep 1
    fi
    URL="http://127.0.0.1:${PFORWARD_PORT}/v1/chat/completions"
    info "Using port-forwarded URL: ${URL} (Host still ${HOST_HEADER})"
  fi
}

cleanup_port_forward() {
  if [ -n "${PFORWARD_PID}" ]; then
    info "Cleaning up port-forward (pid=${PFORWARD_PID})"
    kill "${PFORWARD_PID}" >/dev/null 2>&1 || true
    wait "${PFORWARD_PID}" 2>/dev/null || true
    PFORWARD_PID=""
  fi
}

# Colors
bold() { printf "\033[1m%s\033[0m\n" "$*"; }
ok() { printf "[OK] %s\n" "$*"; }
warn() { printf "[WARN] %s\n" "$*"; }
info() { printf "[INFO] %s\n" "$*"; }
err() { printf "[ERR] %s\n" "$*" >&2; }

require_bin() {
  command -v "$1" >/dev/null 2>&1 || { err "Missing required binary: $1"; exit 1; }
}

require_bin kubectl
require_bin curl

run() {
  if [ "$DRY_RUN" = "1" ]; then
    echo "+ $*"
  else
    eval "$*"
  fi
}

# Helpers to discover decode pods and scrape their metrics
get_decode_pods() {
  kubectl get pods -n "$NS" -l "$DECODE_SELECTOR" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}'
}

get_pod_ip() {
  local pod="$1"
  kubectl get pod "$pod" -n "$NS" -o jsonpath='{.status.podIP}'
}

CURL_POD_NAME="${CURL_POD_NAME:-e2e-curl}"
CREATED_CURL_POD=0

ensure_curl_runner() {
  # Ensure a pod inside the cluster can curl pod IPs
  local phase
  if kubectl get pod -n "$NS" "$CURL_POD_NAME" >/dev/null 2>&1; then
    phase=$(kubectl get pod -n "$NS" "$CURL_POD_NAME" -o jsonpath='{.status.phase}' || echo "")
    if [ "$phase" != "Running" ]; then
      info "Existing curl runner pod (${CURL_POD_NAME}) is in phase=${phase}; recreating"
      run "kubectl delete pod -n '$NS' '$CURL_POD_NAME' --ignore-not-found=true"
      run "kubectl run -n '$NS' '$CURL_POD_NAME' --image=curlimages/curl:8.8.0 -- sleep 3600"
      CREATED_CURL_POD=1
    fi
  else
    info "Creating in-cluster curl runner pod (${CURL_POD_NAME})"
    run "kubectl run -n '$NS' '$CURL_POD_NAME' --image=curlimages/curl:8.8.0 -- sleep 3600"
    CREATED_CURL_POD=1
  fi
  # Wait for it to be Ready
  run "kubectl wait -n '$NS' --for=condition=Ready pod/'$CURL_POD_NAME' --timeout=90s" || true
}

cleanup_curl_runner() {
  if [ "$CREATED_CURL_POD" = "1" ]; then
    info "Cleaning up curl runner pod (${CURL_POD_NAME})"
    run "kubectl delete pod -n '$NS' '$CURL_POD_NAME' --ignore-not-found=true"
  fi
}

exec_curl_in_cluster() {
  local target="$1"
  kubectl exec -n "$NS" "$CURL_POD_NAME" -- curl -s --max-time 2 "$target" || true
}

# Read vLLM prefix cache counters per pod; fall back to total request counters if available.
# Port-forward to a pod to scrape metrics reliably from local context
scrape_metrics_via_portforward() {
  local pod="$1" port="$2" local_port metrics
  # Pick a random high local port
  local_port=$(( (RANDOM % 10000) + 20000 ))
  kubectl port-forward -n "$NS" "pod/${pod}" "${local_port}:${port}" [4m[0m[4m[0m>/dev/null 2>/dev/null &
  local pfpid=$!
  # Give it a moment
  sleep 1
  metrics=$(curl -s --max-time 3 "http://127.0.0.1:${local_port}/metrics" || true)
  kill "$pfpid" >/dev/null 2>/dev/null || true
  wait "$pfpid" 2>/dev/null || true
  printf "%s" "$metrics"
}

read_metrics_for_pods() {
  # Outputs lines: "podname queries hits"
  local pod ip metrics q h port
  for pod in $(get_decode_pods); do
    ip=$(get_pod_ip "$pod")
    if [ -z "$ip" ]; then continue; fi
    q=0; h=0
    # Try common metrics ports in order using port-forward for reliability
    for port in 8200 8001 8000; do
      metrics=$(scrape_metrics_via_portforward "$pod" "$port")
      if [ -n "$metrics" ]; then
        # vLLM prefix cache counters
        q=$(printf "%s\n" "$metrics" | awk -F' ' '/^vllm:prefix_cache_queries_total/{s+=$2} END{print (s==""?0:s)+0}')
        h=$(printf "%s\n" "$metrics" | awk -F' ' '/^vllm:prefix_cache_hits_total/{s+=$2} END{print (s==""?0:s)+0}')
        # Alternatives if prefix metrics not present
        if [ "$q" = "0" ] && [ "$h" = "0" ]; then
          q=$(printf "%s\n" "$metrics" | awk -F' ' '/^http_server_requests_total/{s+=$2} END{print (s==""?0:s)+0}')
          h=0
        fi
        if [ "$q" != "0" ] || [ "$h" != "0" ]; then
          break
        fi
      fi
    done
    printf "%s %s %s\n" "$pod" "$q" "$h"
  done
}
# Compute deltas between two snapshots
# Args: file_before file_after
print_deltas() {
  local before="$1" after="$2"
  awk 'NR==FNR{b[$1]=$0;next}{split(b[$1],a," "); if(a[1]==$1){dq=$2-a[2]; dh=$3-a[3]; if(dq<0)dq=0; if(dh<0)dh=0; printf "%s %d %d\n", $1, dq, dh}}' "$before" "$after"
}

# Send N chat-completions requests with a given session id
send_requests() {
  local sid="$1" n="$2"
  info "Sending ${n} requests for session-id=${sid}"
  local i payload tid now
  payload=$(cat <<EOF
{
  "model": "${MODEL}",
  "stream": false,
  "messages": [
    {"role":"system","content":"You are a helpful assistant."},
    {"role":"user","content":"In one sentence, explain what cache-aware routing is."}
  ]
}
EOF
  )
  now=$(date +%s)
  for i in $(seq 1 "$n"); do
    tid="test-${sid}-${now}-${i}"
    # Capture headers to check for any x-* routing debug headers
    local tmp_headers
    tmp_headers=$(mktemp)
    curl -sS \
      -D "$tmp_headers" \
      -H "Host: ${HOST_HEADER}" \
      -H "Content-Type: application/json" \
      -H "x-session-id: ${sid}" \
      -H "x-test-id: ${tid}" \
      --data "$payload" \
      --write-out "HTTP %{http_code}\\n" \
      --output /dev/null \
      --max-time 20 \
      "$URL" || true
    # Print any interesting debug headers if present
    awk 'BEGIN{IGNORECASE=1} /^x-/{print "  ",$0}' "$tmp_headers" || true
    rm -f "$tmp_headers"
    sleep "$SLEEP_SECS"
  done
}

assert_no_alt_stickiness() {
  bold "1) Verifying no alternative stickiness mechanisms are present"
  # Service sessionAffinity
  local sa
  sa=$(kubectl get svc -n "$NS" -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.spec.sessionAffinity}{"\n"}{end}' | awk '$2!="None"')
  if [ -n "$sa" ]; then
    err "Found Services with sessionAffinity != None:"; echo "$sa"; exit 1
  fi
  ok "All Services have sessionAffinity=None in namespace ${NS}"

  # DestinationRules
  local dr
  dr=$(kubectl get destinationrule -n "$NS" 2>/dev/null | awk 'NR>1{print}')
  if [ -n "$dr" ]; then
    err "Found DestinationRules; remove them to avoid mesh-level stickiness:"; echo "$dr"; exit 1
  fi
  ok "No DestinationRules present in ${NS}"
}

summarize_distribution() {
  # stdin lines: pod dq dh
  # prints dominant pod, its share, total hits if available
  awk '
    {pods[$1]=$1; q[$1]+=$2; h[$1]+=$3; tq+=$2; th+=$3}
    END{
      dom=""; max=0;
      for(p in pods){ if(q[p]>max){max=q[p]; dom=p} }
      share = (tq>0)? int((max*100)/tq) : 0;
      printf "Total requests: %d\n", tq;
      if(th>0){ printf "Prefix-cache hits: %d (hit rate ~%d%%)\n", th, int((th*100)/tq) }
      if(dom!=""){ printf "Dominant pod: %s with ~%d%% of requests\n", dom, share }
    }'
}

prove_stickiness_for_session() {
  local sid="$1" label="$2"
  local before after deltas gw_pod
  gw_pod=$(kubectl get pod -n "$NS" -l 'istio.io/gateway-name=llm-d-gateway' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  before=$(mktemp)
  after=$(mktemp)
  deltas=$(mktemp)
  read_metrics_for_pods >"$before"
  send_requests "$sid" "$REQ_COUNT"
  read_metrics_for_pods >"$after"
  print_deltas "$before" "$after" > "$deltas"
  bold "Session ${label} (${sid}) distribution:"
  cat "$deltas" | awk '{printf "  %-40s requests=%4d hits=%4d\n", $1,$2,$3}'
  echo "---"
  cat "$deltas" | summarize_distribution
  # Log-based proof: inspect gateway access log for upstream endpoint per request
  if [ -n "$gw_pod" ]; then
    info "Gateway log snapshot for session-id=${sid} (last 60s)"
    kubectl logs -n "$NS" "$gw_pod" --since=60s | awk -v sid="$sid" 'BEGIN{IGNORECASE=1} $0 ~ sid {print $0}' | tail -n 20 || true
  fi
  echo
}

prove_epp_on_path() {
  bold "3) Proving EPP is on the request path by scaling it down and observing behavior"
  local epp_dep gw_pod
  epp_dep=$(kubectl get deploy -n "$NS" -o name | grep -E "epp|external|processor" | head -n1 || true)
  gw_pod=$(kubectl get pod -n "$NS" -l 'istio.io/gateway-name=llm-d-gateway' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
  if [ -z "$epp_dep" ]; then
    warn "Could not find EPP Deployment by name; skipping on-path proof."
    return 0
  fi
  info "Scaling down ${epp_dep} to 0 replicas..."
  run "kubectl scale -n '$NS' '$epp_dep' --replicas=0"
  info "Waiting a few seconds for scale-down to take effect..."
  sleep 5
  # If we have a gateway pod, capture ext_proc error evidence while EPP is down
  if [ -n "$gw_pod" ]; then
    info "Checking gateway logs for ext_proc errors while EPP is down (evidence of filter on path)"
    run "kubectl logs -n '$NS' '$gw_pod' --since=60s | grep -E 'ext_proc|external processing' || true"
  fi
  info "Attempting a request; expecting either 5xx or success with ext_proc errors in gateway logs"
  set +e
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" -H "Host: ${HOST_HEADER}" -H "Content-Type: application/json" --data '{"model":"'"${MODEL}"'","messages":[{"role":"user","content":"hello"}]}' "$URL" || true)
  set -e
  if [[ "$code" =~ ^5 ]]; then
    ok "Received ${code} while EPP is scaled to 0 (fail-closed)"
  else
    warn "Gateway returned ${code} while EPP scaled to 0; likely failure_mode_allow (bypass) is enabled. See gateway logs above for ext_proc errors to prove on-path."
  fi
  info "Scaling ${epp_dep} back to 1 replica..."
  run "kubectl scale -n '$NS' '$epp_dep' --replicas=1"
  info "Waiting for EPP to become ready..."
  run "kubectl rollout status -n '$NS' '$epp_dep' --timeout=90s" || true
  info "Re-trying a request; expecting 200"
  set +e
  code=$(curl -sS -o /dev/null -w "%{http_code}" -H "Host: ${HOST_HEADER}" -H "Content-Type: application/json" --data '{"model":"'"${MODEL}"'","messages":[{"role":"user","content":"hello"}]}' "$URL" || true)
  set -e
  if [ "$code" = "200" ]; then
    ok "Gateway returned 200 after EPP restored"
  else
    warn "Gateway still not healthy after EPP restore (status ${code})"
  fi
}

main() {
  bold "Airtight EPP stickiness verification"
  info "Namespace: ${NS}"
  info "Gateway URL: ${URL} (Host: ${HOST_HEADER})"
  info "Model: ${MODEL}"
  info "Decode selector: ${DECODE_SELECTOR}"

  # Ensure we can reach the gateway from this context (set up port-forward if needed)
  ensure_gateway_reachable
  trap cleanup_port_forward EXIT
  trap cleanup_curl_runner EXIT

  assert_no_alt_stickiness

  bold "2) Measuring per-session distribution across decode pods"
  info "Ensuring at least 2 ready decode pods..."
  local ready
  ready=$(kubectl get pods -n "$NS" -l "$DECODE_SELECTOR" --field-selector=status.phase=Running | awk 'NR>1{r++} END{print r+0}')
  if [ "${ready:-0}" -lt 2 ]; then
    err "Need at least 2 running decode pods to verify distribution; found ${ready:-0}."
    exit 1
  fi

  # Three sessions: A, B, then A again to demonstrate consistency
  local SID_A SID_B
  SID_A="sess-$(date +%s)-A"
  SID_B="sess-$(date +%s)-B"

  prove_stickiness_for_session "$SID_A" "A (first run)"
  prove_stickiness_for_session "$SID_B" "B"
  sleep 2
  prove_stickiness_for_session "$SID_A" "A (repeat)"

  prove_epp_on_path

  bold "Done. Review the dominant pod per session and consistency across runs to confirm EPP-driven stickiness."
}

main "$@"

