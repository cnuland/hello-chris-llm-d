# Production-ready LLM-D Installation Makefile
# Follows official community best practices for out-of-box experience

NS ?= llm-d
RELEASE ?= llm-d-infra
GATEWAY_CLASS ?= istio
HF_TOKEN ?= $(shell echo $$HF_TOKEN)

.PHONY: help install-all infra llm-d test status clean
.PHONY: infra-uninstall validate tekton tekton-run monitoring

help:
	@echo "🚀 LLM-D Production Installation Commands"
	@echo ""
	@echo "📦 Primary Commands:"
	@echo "  install-all     - Complete installation (infra + llm-d + test)"
	@echo "  infra          - Install infrastructure (Gateway, HTTPRoute)"
	@echo "  llm-d          - Install LLM-D components (EPP, decode services)"
	@echo "  test           - Run cache-hit validation test"
	@echo "  status         - Check deployment status"
	@echo "  clean          - Remove all components"
	@echo ""
	@echo "🔧 Utility Commands:"
	@echo "  validate       - Run Tekton validation pipeline"
	@echo "  monitoring     - Deploy monitoring stack (Prometheus, Grafana)"
	@echo "  tekton-run     - Start new cache-hit test"
	@echo ""
	@echo "📋 Environment Variables:"
	@echo "  NS=<namespace>     (default: llm-d)"
	@echo "  HF_TOKEN=<token>   (required for model access)"
	@echo "  GATEWAY_CLASS=<class> (default: istio)"
	@echo ""
	@echo "⚠️  Prerequisites:"
	@echo "  - Istio 1.27.0+ installed"
	@echo "  - Gateway API CRDs installed"
	@echo "  - NVIDIA GPU Operator (for GPU acceleration)"
	@echo "  - HF_TOKEN environment variable set"

# Complete installation workflow
install-all: infra llm-d test
	@echo "✅ Complete LLM-D installation finished successfully!"
	@echo "📊 Cache hit validation results shown above"
	@echo "🔍 Use 'make status' to monitor ongoing performance"

# Step 1: Install infrastructure (Gateway, HTTPRoute, base services)
infra:
	@echo "📦 [1/4] Installing LLM-D Infrastructure"
	@echo "🔍 Ensuring namespace $(NS) exists"
	@oc get namespace $(NS) >/dev/null 2>&1 || oc create namespace $(NS)
	@if [ -n "$(HF_TOKEN)" ]; then \
	  echo "🔑 Creating HuggingFace token secret"; \
	  oc -n $(NS) create secret generic llm-d-hf-token --from-literal=HF_TOKEN="$(HF_TOKEN)" --dry-run=client -o yaml | oc apply -f - >/dev/null; \
	else \
	  echo "⚠️  HF_TOKEN not set - model access may fail"; \
	fi
	@echo "📥 Adding Helm repositories"
	@helm repo add llm-d-infra https://llm-d-incubation.github.io/llm-d-infra/ >/dev/null 2>&1 || true
	@helm repo update >/dev/null 2>&1
	@echo "⚙️  Installing infrastructure Helm chart ($(RELEASE))"
	@helm upgrade -i $(RELEASE) llm-d-infra/llm-d-infra -n $(NS) \
	  --create-namespace \
	  --set gateway.gatewayClassName=$(GATEWAY_CLASS) \
	  --timeout=10m >/dev/null
	@echo "✅ Infrastructure installation complete"
	@echo "🔍 Verifying gateway status..."
	@oc get gateway -n $(NS) -o custom-columns=NAME:.metadata.name,PROGRAMMED:.status.conditions[0].status 2>/dev/null || echo "⚠️  Gateway status check failed - may still be initializing"

# Step 2: Install LLM-D components (EPP, decode services, EnvoyFilters)
llm-d:
	@echo "🚀 [2/4] Installing LLM-D Components"
	@echo "📦 Applying decode services and deployment"
	@oc apply -n $(NS) -f assets/llm-d/decode-service.yaml >/dev/null
	@oc apply -n $(NS) -f assets/llm-d/decode-deployment.yaml >/dev/null
	@oc apply -n $(NS) -f assets/llm-d/httproute.yaml >/dev/null
	@echo "🧠 Installing EPP (External Processing Pod) for cache-aware routing"
	@oc apply -n $(NS) -f assets/llm-d/epp.yaml >/dev/null
	@oc apply -n $(NS) -f assets/inference-crs.yaml >/dev/null
	@echo "🔗 Configuring Istio EnvoyFilters for intelligent routing"
	@oc apply -n $(NS) -f assets/envoyfilter-epp.yaml >/dev/null
	@oc apply -n $(NS) -f assets/envoyfilter-gateway-access-logs.yaml >/dev/null
	@oc apply -n $(NS) -f assets/envoyfilter-gateway-lua-upstream-header.yaml >/dev/null
	@oc apply -n $(NS) -f assets/envoyfilter-gateway-add-upstream-header.yaml >/dev/null
	@oc apply -n $(NS) -f assets/gateway-session-header-normalize.yaml >/dev/null
	@oc apply -n $(NS) -f assets/llm-d/destinationrule-decode.yaml >/dev/null
	@echo "⚙️  Updating DestinationRule for session consistency"
	@oc -n $(NS) patch destinationrule ms-llm-d-modelservice-decode --type=json -p='[{"op":"remove","path":"/spec/trafficPolicy/loadBalancer/simple"},{"op":"add","path":"/spec/trafficPolicy/loadBalancer/consistentHash","value":{"httpHeaderName":"x-session-id","minimumRingSize":4096}}]' >/dev/null 2>&1 || true
	@echo "🔄 Restarting gateway to apply configuration changes"
	@oc -n $(NS) rollout restart deploy/llm-d-infra-inference-gateway-istio >/dev/null
	@oc -n $(NS) rollout status deploy/llm-d-infra-inference-gateway-istio --timeout=180s >/dev/null
	@echo "⏳ Waiting for services to be ready (this may take 5-10 minutes for GPU model loading)"
	@echo "   - Decode services loading models on GPU..."
	@oc rollout status deploy/ms-llm-d-modelservice-decode -n $(NS) --timeout=600s >/dev/null || echo "⚠️  Decode deployment timeout - check logs: oc logs -n $(NS) -l app=ms-llm-d-modelservice-decode"
	@echo "   - EPP service starting..."
	@oc rollout status deploy/ms-llm-d-modelservice-epp -n $(NS) --timeout=300s >/dev/null || echo "⚠️  EPP deployment timeout - check logs: oc logs -n $(NS) -l app=ms-llm-d-modelservice-epp"
	@echo "✅ LLM-D components installation complete"

# Step 3: Run validation test
test:
	@echo "🧪 [3/4] Running Cache-Hit Validation Test"
	@echo "📊 Starting Tekton pipeline for cache performance validation..."
	@oc apply -n $(NS) -f assets/cache-aware/tekton/cache-hit-pipeline.yaml >/dev/null
	@oc create -n $(NS) -f assets/cache-aware/tekton/cache-hit-pipelinerun.yaml >/dev/null
	@echo "📈 Streaming test results (Ctrl-C to stop):"
	@echo ""
	@tkn pipelinerun logs -n $(NS) --last -f --all || echo "⚠️  Tekton CLI not available - check results manually: oc logs -n $(NS) -l tekton.dev/pipelineRun"

# Check deployment status
status:
	@echo "📊 LLM-D Deployment Status"
	@echo ""
	@echo "🏗️  Infrastructure:"
	@oc get gateway,httproute -n $(NS) -o custom-columns=KIND:.kind,NAME:.metadata.name,STATUS:.status.conditions[0].status 2>/dev/null || echo "No gateway resources found"
	@echo ""
	@echo "🚀 LLM-D Components:"
	@oc get pods -n $(NS) -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount 2>/dev/null || echo "No pods found in namespace $(NS)"
	@echo ""
	@echo "💾 GPU Resources:"
	@oc describe nodes -l nvidia.com/gpu.present=true | grep -E "nvidia.com/gpu|Allocated resources" | head -10 || echo "No GPU resources found"
	@echo ""
	@echo "📈 Recent Cache Performance:"
	@echo "Use 'make test' to run new validation or check Grafana dashboards"

# Deploy monitoring stack (optional)
monitoring:
	@echo "📊 Deploying Monitoring Stack"
	@oc apply -n $(NS) -f monitoring/ >/dev/null
	@echo "✅ Monitoring deployed - access Grafana via the route created in monitoring/"

# Run new validation test
tekton-run:
	@echo "🧪 Starting New Cache-Hit Test"
	@oc create -n $(NS) -f assets/cache-aware/tekton/cache-hit-pipelinerun.yaml >/dev/null
	@echo "📊 Stream results: tkn pipelinerun logs -n $(NS) --last -f --all"

# Full validation with detailed output
validate:
	@echo "🔬 Running Detailed Validation"
	@oc apply -n $(NS) -f assets/cache-aware/tekton/cache-hit-pipeline.yaml >/dev/null
	@oc create -n $(NS) -f assets/cache-aware/tekton/cache-hit-pipelinerun.yaml >/dev/null
	@echo "📈 Detailed validation results:"
	@tkn pipelinerun logs -n $(NS) --last -f --all

# Clean installation (removes everything)
clean:
	@echo "🧹 Cleaning LLM-D Installation"
	@echo "⚠️  This will remove ALL LLM-D components from namespace $(NS)"
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	@echo "🗑️  Removing LLM-D assets"
	@oc delete -n $(NS) -f assets/llm-d/ --ignore-not-found=true >/dev/null 2>&1 || true
	@oc delete -n $(NS) -f assets/envoyfilter-*.yaml --ignore-not-found=true >/dev/null 2>&1 || true
	@oc delete -n $(NS) -f assets/gateway-*.yaml --ignore-not-found=true >/dev/null 2>&1 || true
	@oc delete -n $(NS) -f assets/inference-crs.yaml --ignore-not-found=true >/dev/null 2>&1 || true
	@echo "🏗️  Removing infrastructure Helm release"
	@helm uninstall $(RELEASE) -n $(NS) >/dev/null 2>&1 || true
	@echo "🗑️  Removing Tekton assets"
	@oc delete -n $(NS) -f assets/cache-aware/tekton/ --ignore-not-found=true >/dev/null 2>&1 || true
	@echo "✅ Clean complete - namespace $(NS) ready for fresh installation"

# Legacy compatibility (deprecated)
infra-uninstall:
	@echo "⚠️  Deprecated: Use 'make clean' for complete removal"
	@helm uninstall $(RELEASE) -n $(NS) || true

assets:
	@echo "[assets] Applying LLM-D assets to $(NS)" && \
	oc apply -n $(NS) -f assets/llm-d/decode-service.yaml && \
	oc apply -n $(NS) -f assets/llm-d/decode-deployment.yaml && \
	oc apply -n $(NS) -f assets/llm-d/httproute.yaml && \
	# EPP (scheduler) and Inference CRs for KV-cache-aware routing
	oc apply -n $(NS) -f assets/llm-d/epp.yaml && \
	oc apply -n $(NS) -f assets/inference-crs.yaml && \
	# Istio EnvoyFilters (ext-proc + access logs + Lua override + session normalization)
	oc apply -n $(NS) -f assets/envoyfilter-epp.yaml && \
	oc apply -n $(NS) -f assets/envoyfilter-gateway-access-logs.yaml && \
	oc apply -n $(NS) -f assets/envoyfilter-gateway-lua-upstream-header.yaml && \
	oc apply -n $(NS) -f assets/envoyfilter-gateway-add-upstream-header.yaml && \
	oc apply -n $(NS) -f assets/gateway-session-header-normalize.yaml && \
	# DestinationRule with consistent-hash stickiness as a safety net
	oc apply -n $(NS) -f assets/llm-d/destinationrule-decode.yaml && \
	# Ensure Helm-provisioned DR switches from ROUND_ROBIN to consistentHash on x-session-id
	oc -n $(NS) patch destinationrule ms-llm-d-modelservice-decode --type=json -p='[{"op":"remove","path":"/spec/trafficPolicy/loadBalancer/simple"},{"op":"add","path":"/spec/trafficPolicy/loadBalancer/consistentHash","value":{"httpHeaderName":"x-session-id","minimumRingSize":4096}}]' || true && \
	# Restart gateway to ensure new EnvoyFilters are picked up
	oc -n $(NS) rollout restart deploy/llm-d-infra-inference-gateway-istio && \
	oc -n $(NS) rollout status deploy/llm-d-infra-inference-gateway-istio --timeout=180s && \
	echo "[assets] Waiting for decode deployment rollout" && \
	oc rollout status deploy/ms-llm-d-modelservice-decode -n $(NS) --timeout=300s && \
	echo "[assets] Waiting for EPP rollout" && \
	oc rollout status deploy/ms-llm-d-modelservice-epp -n $(NS) --timeout=300s

tekton:
	@echo "[tekton] Applying Tekton cache-hit pipeline/task" && \
	oc apply -n $(NS) -f assets/cache-aware/tekton/cache-hit-pipeline.yaml && \
	oc create -n $(NS) -f assets/cache-aware/tekton/cache-hit-pipelinerun.yaml
	@echo "[tekton] To stream logs: tkn pipelinerun logs -n $(NS) --last -f --all"

# Apply only the session stickiness tuning knobs (DestinationRule + Envoy/Lua override)
.PHONY: tune-stickiness
tune-stickiness:
	@echo "[tune] Applying DestinationRule and gateway overrides for stickiness" && \
	oc apply -n $(NS) -f assets/llm-d/destinationrule-decode.yaml && \
	oc apply -n $(NS) -f assets/envoyfilter-gateway-lua-upstream-header.yaml && \
	oc apply -n $(NS) -f assets/envoyfilter-gateway-add-upstream-header.yaml && \
	oc apply -n $(NS) -f assets/gateway-session-header-normalize.yaml \
		&& oc apply -n $(NS) -f assets/gateway-epp-destination-override.yaml \
		&& echo "[tune] Restarting gateway to pick up filters"
	oc -n $(NS) rollout restart deploy/llm-d-infra-inference-gateway-istio && \
	oc -n $(NS) rollout status deploy/llm-d-infra-inference-gateway-istio --timeout=120s

# Roll back stickiness tuning (remove DestinationRule)
.PHONY: rollback-stickiness
rollback-stickiness:
	@echo "[rollback] Removing DestinationRule-based stickiness" && \
	oc -n $(NS) delete destinationrule ms-llm-d-modelservice-decode-session-affinity --ignore-not-found=true

# Legacy helpers (kept for backwards compatibility)
# Keeps existing install flow if you already have scripts/make-demo.sh
# Otherwise it will print a helpful message.
demo:
	@if [ -x scripts/make-demo.sh ]; then \
	  NS=$(NS) scripts/make-demo.sh; \
	else \
	  echo "scripts/make-demo.sh not found or not executable."; \
	  echo "Please use 'make infra' for the mandated install path."; \
	  exit 1; \
	fi

uninstall:
	@if [ -x scripts/make-demo-uninstall.sh ]; then \
	  NS=$(NS) scripts/make-demo-uninstall.sh; \
	else \
	  echo "scripts/make-demo-uninstall.sh not found or not executable."; \
	  echo "Consider 'make infra-uninstall' to remove the Helm release."; \
	fi

