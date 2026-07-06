# Task 03 — Incident Scenarios

For each scenario I selected the action I would actually take **first** in a real
production environment, with a short reasoning. (Per the brief, there are no
strictly wrong answers — these reflect my first move and the thinking behind it.)

---

## Question 1 — Service returning 503

**Choice: A** — Check logs for error patterns in the last 5–10 minutes to identify the failure mode.

**Reasoning:** Logs are the fastest, non-destructive way to identify the actual
failure mode of a 503 (exhausted/unhealthy backends, dependency or DB timeouts,
resource exhaustion, or a library broken by a recent update), so I can choose the
right mitigation — roll back, scale, or fail over — instead of rolling back
blindly, which can be useless or spread the failure. If the logs are clean, the
fault is likely external, so I next verify dependencies/DB (D), then host
resources (C).

---

## Question 2 — Alert storm after a config change

**Choice: D** — Check whether the alerting/monitoring system itself is affected by the config change.

**Reasoning:** A config push that triggers 200 simultaneous alerts across many
services is far more consistent with the change breaking the monitoring pipeline
(e.g., label/relabel changes causing NoData or false positives) than with 200
independent real failures, which normally ramp up service-by-service rather than
all at once. I do a ~30-second sanity check that the alerts are real (synthetic
checks / actual user-facing errors); if they are false I avoid a panic rollback,
and if they are real I immediately roll back to the last known-good state.

---

## Question 3 — Latency spike, no alert fired

**Choice: D** — The issue escalated gradually without ever crossing a single alerting threshold.

**Reasoning:** The latency stayed under the static alert threshold so nothing
fired, but 200ms → 2s is a severe regression against what users actually
experience — which is why they complain while the system is technically "within
limits." My immediate concern is that alerting is built on static absolute
thresholds rather than user-facing SLOs / burn-rate alerting (and likely lacks
synthetic monitoring for low-traffic periods), so gradual, user-visible
degradations slip through until someone notices manually.

---
