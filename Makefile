# Simple Makefile for demo install/uninstall helpers

NS ?= llm-d
RELEASE ?= llm-d-infra
GATEWAY_CLASS ?= istio

.PHONY: help demo uninstall infra infra-uninstall infra-status

help:
	@echo "Targets:"
	@echo "  infra           - Install/upgrade llm-d-infra Helm chart (MANDATED PATH)"
	@echo "  infra-uninstall - Uninstall llm-d-infra Helm release"
	@echo "  infra-status    - Show Helm release status"
	@echo "  assets          - Apply LLM-D assets (HTTPRoute, EnvoyFilters, decode svc/deploy)"
	@echo "  tekton          - Apply Tekton validator pipeline/tasks and start a run"
	@echo "  tekton-run      - Start a new cache-hit PipelineRun"
	@echo "  demo            - Legacy demo installer (if scripts/make-demo.sh exists)"
	@echo "  uninstall       - Legacy demo uninstaller (if scripts/make-demo-uninstall.sh exists)"
	@echo "Variables:"
	@echo "  NS=\u003cnamespace\u003e (default: llm-d)"
	@echo "  RELEASE=\u003chelm release name\u003e (default: llm-d-infra)"
	@echo "  GATEWAY_CLASS=\u003ckgateway|istio|gke-l7-regional-external-managed\u003e (default: istio)"
	@echo "  HF_TOKEN available in env to seed llm-d-hf-token (optional)"

# MANDATED installation path: llm-d-infra Helm chart
infra:
	@echo "[infra] Ensuring namespace $(NS) exists" && \
	kubectl get namespace $(NS) >/dev/null 2>&1 || kubectl create namespace $(NS);
	@if [ -n "$$HF_TOKEN" ]; then \
	  echo "[infra] Applying HuggingFace token secret to $(NS)"; \
	  kubectl -n $(NS) create secret generic llm-d-hf-token --from-literal=HF_TOKEN="$$HF_TOKEN" --dry-run=client -o yaml | kubectl apply -f -; \
	else \
	  echo "[infra] HF_TOKEN not set; proceeding without creating/updating llm-d-hf-token secret"; \
	fi
	@echo "[infra] Adding Helm repos" && \
	helm repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 || true; \
	helm repo add llm-d-infra https://llm-d-incubation.github.io/llm-d-infra/ >/dev/null 2>&1 || true; \
	helm repo update >/dev/null
	@echo "[infra] Installing/upgrading release $(RELEASE) in namespace $(NS) with gatewayClass=$(GATEWAY_CLASS)" && \
	helm upgrade -i $(RELEASE) llm-d-infra/llm-d-infra -n $(NS) --create-namespace --set gateway.gatewayClassName=$(GATEWAY_CLASS)

infra-uninstall:
	@echo "[infra] Uninstalling release $(RELEASE) from namespace $(NS)" 66 \
	helm uninstall $(RELEASE) -n $(NS) || true

infra-status:
	@helm status $(RELEASE) -n $(NS) || true

assets:
	@echo "[assets] Applying LLM-D assets to $(NS)" && \
	kubectl apply -n $(NS) -f assets/llm-d/decode-service.yaml && \
	kubectl apply -n $(NS) -f assets/llm-d/decode-deployment.yaml && \
	kubectl apply -n $(NS) -f assets/llm-d/httproute.yaml && \
	# EPP (scheduler) and Inference CRs for KV-cache-aware routing
	kubectl apply -n $(NS) -f assets/llm-d/epp.yaml && \
	kubectl apply -n $(NS) -f assets/inference-crs.yaml && \
	# Istio EnvoyFilters (ext-proc + access logs + Lua override + session normalization)
	kubectl apply -n $(NS) -f assets/envoyfilter-epp.yaml && \
	kubectl apply -n $(NS) -f assets/envoyfilter-gateway-access-logs.yaml && \
	kubectl apply -n $(NS) -f assets/envoyfilter-gateway-lua-upstream-header.yaml && \
	kubectl apply -n $(NS) -f assets/envoyfilter-gateway-add-upstream-header.yaml && \
	kubectl apply -n $(NS) -f assets/gateway-session-header-normalize.yaml && \
	# DestinationRule with consistent-hash stickiness as a safety net
	kubectl apply -n $(NS) -f assets/llm-d/destinationrule-decode.yaml && \
	# Ensure Helm-provisioned DR switches from ROUND_ROBIN to consistentHash on x-session-id
	kubectl -n $(NS) patch destinationrule ms-llm-d-modelservice-decode --type=json -p='[{"op":"remove","path":"/spec/trafficPolicy/loadBalancer/simple"},{"op":"add","path":"/spec/trafficPolicy/loadBalancer/consistentHash","value":{"httpHeaderName":"x-session-id","minimumRingSize":4096}}]' || true && \
	# Restart gateway to ensure new EnvoyFilters are picked up
	kubectl -n $(NS) rollout restart deploy/llm-d-infra-inference-gateway-istio && \
	kubectl -n $(NS) rollout status deploy/llm-d-infra-inference-gateway-istio --timeout=180s && \
	echo "[assets] Waiting for decode deployment rollout" && \
	kubectl rollout status deploy/ms-llm-d-modelservice-decode -n $(NS) --timeout=300s && \
	echo "[assets] Waiting for EPP rollout" && \
	kubectl rollout status deploy/ms-llm-d-modelservice-epp -n $(NS) --timeout=300s

tekton:
	@echo "[tekton] Applying Tekton cache-hit pipeline/task" && \
	kubectl apply -n $(NS) -f assets/cache-aware/tekton/cache-hit-pipeline.yaml && \
	kubectl create -n $(NS) -f assets/cache-aware/tekton/cache-hit-pipelinerun.yaml
	@echo "[tekton] To stream logs: tkn pipelinerun logs -n $(NS) --last -f --all"

tekton-run:
	@kubectl create -n $(NS) -f assets/cache-aware/tekton/cache-hit-pipelinerun.yaml && \
	echo "[tekton] Run created. Stream: tkn pipelinerun logs -n $(NS) --last -f --all"

# Apply only the session stickiness tuning knobs (DestinationRule + Envoy/Lua override)
.PHONY: tune-stickiness
tune-stickiness:
	@echo "[tune] Applying DestinationRule and gateway overrides for stickiness" && \
	kubectl apply -n $(NS) -f assets/llm-d/destinationrule-decode.yaml && \
	kubectl apply -n $(NS) -f assets/envoyfilter-gateway-lua-upstream-header.yaml && \
	kubectl apply -n $(NS) -f assets/envoyfilter-gateway-add-upstream-header.yaml && \
	kubectl apply -n $(NS) -f assets/gateway-session-header-normalize.yaml \
		&& kubectl apply -n $(NS) -f assets/gateway-epp-destination-override.yaml \
		&& echo "[tune] Restarting gateway to pick up filters"
	kubectl -n $(NS) rollout restart deploy/llm-d-infra-inference-gateway-istio && \
	kubectl -n $(NS) rollout status deploy/llm-d-infra-inference-gateway-istio --timeout=120s

# Validate: run the cache-hit pipeline and stream logs
.PHONY: validate
validate:
	@kubectl apply -n $(NS) -f assets/cache-aware/tekton/cache-hit-pipeline.yaml && \
	kubectl create -n $(NS) -f assets/cache-aware/tekton/cache-hit-pipelinerun.yaml && \
	echo "[validate] Streaming logs (Ctrl-C to stop)…" && \
	tkn pipelinerun logs -n $(NS) --last -f --all

# Roll back stickiness tuning (remove DestinationRule)
.PHONY: rollback-stickiness
rollback-stickiness:
	@echo "[rollback] Removing DestinationRule-based stickiness" && \
	kubectl -n $(NS) delete destinationrule ms-llm-d-modelservice-decode-session-affinity --ignore-not-found=true

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

