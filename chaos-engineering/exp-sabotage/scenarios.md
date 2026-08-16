# Chaos Engineering Experiments — DevSecOps Chaos Lab

Experiment catalog and runbook for validating self-healing behavior in the sample-app deployment.

---

## Experiment Overview

Each experiment is designed to test a specific failure mode and validate that Kubernetes auto-recovery mechanisms maintain service availability within SLO windows.

### SLO Targets

| Metric | Target | Window |
|--------|--------|--------|
| Pod Recovery Time | ≤ 90 seconds from disruption | Per experiment |
| Service Availability | ≥ 99.5% during chaos window | Full duration |
| No Cascade Failures | Zero side-effect on co-located workloads | Post-experiment |

---

## Experiment List

### 1. Pod Failure (pod-failure.yaml)

**Objective:** Verify that when a sample-app pod is terminated, Kubernetes automatically spawns a replacement within SLO and traffic continues uninterrupted.

**Method:**
- LitmusChaos `pod-delete` chaos engine
- Targets pods labeled `app=sample-app` in the target namespace
- Deletes one pod at a time (respecting replica count)

**Validation Criteria:**
1. Pod is terminated within 30 seconds of experiment start
2. New pod enters `Running` state within 90 seconds
3. `readyReplicas` returns to desired count within 90 seconds
4. `/healthz` endpoint responds successfully on new pods
5. No other pods or namespaces affected

**Expected Duration:** 60-120 seconds (deletion + scheduling + startup)

---

### 2. Network Latency (network-latency.yaml)

**Objective:** Verify that the sample-app maintains health check pass/fail status when network latency is injected between the pod and its Service endpoint.

**Method:**
- LitmusChaos `network-latency` chaos engine
- Injects configurable latency (default: 500ms) on traffic to/from target pods
- Simulates real-world conditions: poor connectivity, VPN delays, CDN issues

**Validation Criteria:**
1. Latency injection applied successfully
2. `/healthz` probe continues to pass despite latency (internal probes unaffected by service mesh latency injection in most cases)
3. `/metrics` endpoint still scrapes correctly for Prometheus
4. No timeout-related errors in application logs
5. Service remains `Available` in Deployment status

**Expected Duration:** 60-90 seconds

---

### 3. OOM Kill (oom-killing.yaml)

**Objective:** Verify that when a pod is killed due to memory pressure, Kubernetes respects resource limits and recovers without impacting the node or other workloads.

**Method:**
- LitmusChaos `container-kill` chaos engine targeting node-level OOM conditions
- Forces the kernel OOM killer to terminate containers exceeding memory limits
- Tests that: (a) resource limits are enforced correctly, (b) restart policies work as expected

**Validation Criteria:**
1. Pod enters `OOMKilled` state in container status
2. Restart count increments (proving restartPolicy=Always works)
3. New pod starts within 60 seconds with fresh memory allocation
4. No node-level impact: no other pods evicted, no node NotReady
5. Memory limits hold: new pod stays within defined `memoryLimit`

**Expected Duration:** 90-120 seconds

---

## Runbook

### Prerequisites

```bash
# Ensure LitmusChaos is installed
kubectl get pods -n litmus
# If empty, install: kubectl apply -f https://github.com/litmuschaos/litmuschaos/releases/latest/download/litmus.yaml
```

### Running a Single Experiment

```bash
# 1. Verify sample-app is running
kubectl get pods -n secops-dev -l app=sample-app

# 2. Apply experiment CR
kubectl apply -f chaos-engineering/exp-sabotage/pod-failure.yaml

# 3. Monitor chaos run
kubectl get chaosruns -n secops-dev -w

# 4. Watch recovery
watch 'kubectl get pods -n secops-dev -l app=sample-app -o wide'

# 5. Clean up experiment
kubectl delete -f chaos-engineering/exp-sabotage/pod-failure.yaml
kubectl delete chaosresult -n secops-dev <experiment-name>
```

### Running Full Suite (Automated)

```bash
for exp in pod-failure network-latency oom-killing; do
  echo "▶ Starting: $exp"
  kubectl apply -f chaos-engineering/exp-sabotage/${exp}.yaml
  
  # Wait for experiment to complete (default duration = 60s)
  until ! kubectl get chaosruns -n secops-dev -o name | grep -q .; do
    sleep 5
  done
  
  echo "✅ $exp completed — cleaning up"
  kubectl delete -f chaos-engineering/exp-sabotage/${exp}.yaml
done
```

### Verifying Chaos Results

```bash
# Check experiment results (success/fail/skipped)
kubectl get chaosresults -n secops-dev -o wide

# Detailed result for a specific experiment
kubectl get chaosresult <experiment-name> -n secops-dev -o yaml | grep -A 10 status
```

---

## Post-Experiment Checklist

After each experiment completes, verify:

- [ ] `kubectl rollout status deployment/sample-app -n <namespace>` → success within SLO
- [ ] `curl -s http://sample-app.secops-dev.svc/healthz` → `{"status":"ok"}`
- [ ] No warnings/errors in pod logs: `kubectl logs deployment/sample-app -n <namespace> --tail=50`
- [ ] Node health unchanged: `kubectl get nodes` → all Ready
- [ ] LitmusChaos chaosresult shows `Status: Successful`

---

## Troubleshooting

| Issue | Check | Fix |
|-------|-------|-----|
| Experiment hangs | `kubectl get chaosruns -n secops-dev` | Verify experiment CR duration, increase if needed |
| Pod doesn't recover | Describe pod events: `kubectl describe pod <pod-name> -n <ns>` | Check resource quotas, node capacity |
| OOM kill not reproducible | Verify resource limits in deployment manifest | Ensure `memory.limit` is set AND container memory usage exceeds it |
| Network latency injection fails | Check iptables rules: `iptables -t mangle -L` | Ensure network policy doesn't block chaos engine traffic |

---

## Design Notes

- Experiments use LitmusChaos CRDs (not raw Kubernetes) for declarative chaos management
- Each experiment defines its own `chaosServiceAccount` with minimal RBAC permissions
- `chaosDuration` and `interval` parameters are tunable per environment
- Experiments include `probe` blocks for pre/post validation (health check before/after)
