"""ToggleMaster self-healing runbook (AWS Lambda).

Triggered by a Grafana Alerting webhook (contact point "togglemaster-oncall").
For every *firing* alert labelled `selfheal="true"` it performs the same
action as `kubectl rollout restart deployment/<name>`, waits for the rollout
to finish and reports the outcome to Slack.

Guardrails (see the "Runbook Automation" / "Self-Healing" lessons):
  * Bearer token check: only Grafana knows the token (Secrets Manager).
  * Allow-list of deployments: the function can't restart anything else, and
    its EKS access entry is scoped to a single namespace.
  * Cooldown: a deployment restarted less than COOLDOWN_SECONDS ago is not
    restarted again, so a persistent failure escalates to humans (PagerDuty)
    instead of looping restarts forever.

Only the Python standard library + boto3/botocore (bundled in the Lambda
runtime) are used, so there is no dependency packaging step.
"""

import base64
import hmac
import json
import logging
import os
import ssl
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

import boto3
from botocore.signers import RequestSigner

log = logging.getLogger()
log.setLevel(logging.INFO)

REGION = os.environ["AWS_REGION"]
CLUSTER_NAME = os.environ["CLUSTER_NAME"]
CLUSTER_ENDPOINT = os.environ["CLUSTER_ENDPOINT"]
CLUSTER_CA = base64.b64decode(os.environ["CLUSTER_CA"]).decode()
SECRET_ARN = os.environ["SECRET_ARN"]
DEFAULT_NAMESPACE = os.environ.get("DEFAULT_NAMESPACE", "togglemaster")
ALLOWED = {d.strip() for d in os.environ.get("ALLOWED_DEPLOYMENTS", "").split(",") if d.strip()}
COOLDOWN_SECONDS = int(os.environ.get("COOLDOWN_SECONDS", "300"))
ROLLOUT_TIMEOUT_SECONDS = int(os.environ.get("ROLLOUT_TIMEOUT_SECONDS", "150"))

RESTART_ANNOTATION = "kubectl.kubernetes.io/restartedAt"
TLS = ssl.create_default_context(cadata=CLUSTER_CA)

_session = boto3.session.Session()
_secrets_cache = None


def _event(msg, **fields):
    """Structured (JSON) log line, easy to search in CloudWatch Logs Insights."""
    log.info(json.dumps({"msg": msg, **fields}, default=str))


def _secrets():
    global _secrets_cache
    if _secrets_cache is None:
        sm = _session.client("secretsmanager", region_name=REGION)
        _secrets_cache = json.loads(sm.get_secret_value(SecretId=SECRET_ARN)["SecretString"])
    return _secrets_cache


# --- Kubernetes API access -------------------------------------------------

def _eks_token():
    """Same token `aws eks get-token` produces: a presigned STS GetCallerIdentity URL."""
    sts = _session.client("sts", region_name=REGION)
    signer = RequestSigner(
        sts.meta.service_model.service_id, REGION, "sts", "v4",
        _session.get_credentials(), _session.events,
    )
    url = signer.generate_presigned_url(
        {
            "method": "GET",
            "url": f"https://sts.{REGION}.amazonaws.com/?Action=GetCallerIdentity&Version=2011-06-15",
            "body": {},
            "headers": {"x-k8s-aws-id": CLUSTER_NAME},
            "context": {},
        },
        region_name=REGION,
        expires_in=60,
        operation_name="",
    )
    return "k8s-aws-v1." + base64.urlsafe_b64encode(url.encode()).decode().rstrip("=")


def _k8s(method, path, body=None, content_type="application/json"):
    req = urllib.request.Request(
        CLUSTER_ENDPOINT + path,
        method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Authorization": f"Bearer {_eks_token()}", "Content-Type": content_type},
    )
    with urllib.request.urlopen(req, context=TLS, timeout=10) as resp:
        return json.loads(resp.read())


def _deployment_path(namespace, name):
    return f"/apis/apps/v1/namespaces/{namespace}/deployments/{name}"


def _last_restart(deploy):
    ann = deploy["spec"]["template"]["metadata"].get("annotations") or {}
    value = ann.get(RESTART_ANNOTATION)
    return datetime.fromisoformat(value.replace("Z", "+00:00")) if value else None


def rollout_restart(namespace, name):
    """Equivalent to `kubectl rollout restart deployment/<name> -n <namespace>`."""
    now = datetime.now(timezone.utc).replace(microsecond=0)
    patch = {"spec": {"template": {"metadata": {"annotations": {RESTART_ANNOTATION: now.isoformat()}}}}}
    return _k8s("PATCH", _deployment_path(namespace, name), patch, "application/strategic-merge-patch+json")


def wait_rollout(namespace, name, generation):
    """Equivalent to `kubectl rollout status`: wait until every replica is new and available."""
    deadline = time.time() + ROLLOUT_TIMEOUT_SECONDS
    while time.time() < deadline:
        d = _k8s("GET", _deployment_path(namespace, name))
        st, want = d.get("status", {}), d["spec"].get("replicas", 1)
        if (
            st.get("observedGeneration", 0) >= generation
            and st.get("updatedReplicas", 0) == want
            and st.get("availableReplicas", 0) == want
            and st.get("replicas", 0) == want
        ):
            return True, st
        time.sleep(5)
    return False, st


# --- Notification -----------------------------------------------------------

def notify_slack(text, fields):
    url = _secrets().get("slack_webhook_url")
    if not url:
        return
    payload = {
        "text": text,
        "blocks": [
            {"type": "section", "text": {"type": "mrkdwn", "text": text}},
            {"type": "section", "fields": [{"type": "mrkdwn", "text": f"*{k}*\n{v}"} for k, v in fields.items()]},
        ],
    }
    req = urllib.request.Request(url, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    try:
        urllib.request.urlopen(req, timeout=5).read()
    except urllib.error.URLError as e:  # never fail the remediation because of chat
        _event("slack_notification_failed", error=str(e))


# --- Handler ----------------------------------------------------------------

def _response(status, body):
    return {"statusCode": status, "headers": {"Content-Type": "application/json"}, "body": json.dumps(body)}


def _authorized(event):
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    expected = f"Bearer {_secrets()['selfheal_token']}"
    return hmac.compare_digest(headers.get("authorization", ""), expected)


def heal(namespace, name, alert):
    started = time.time()
    current = _k8s("GET", _deployment_path(namespace, name))
    last = _last_restart(current)
    if last and (datetime.now(timezone.utc) - last).total_seconds() < COOLDOWN_SECONDS:
        _event("skipped_cooldown", deployment=name, last_restart=last)
        notify_slack(
            f":warning: *Self-healing skipped* for `{name}`: restarted less than {COOLDOWN_SECONDS}s ago. "
            "Escalating to the on-call engineer (PagerDuty).",
            {"Deployment": f"{namespace}/{name}", "Last restart": last.isoformat()},
        )
        return {"deployment": name, "action": "skipped_cooldown"}

    _event("rollout_restart", deployment=name, namespace=namespace, alert=alert.get("labels", {}).get("alertname"))
    patched = rollout_restart(namespace, name)
    ok, status = wait_rollout(namespace, name, patched["metadata"]["generation"])
    elapsed = round(time.time() - started, 1)
    _event("rollout_finished", deployment=name, healthy=ok, seconds=elapsed, status=status)

    summary = (alert.get("annotations") or {}).get("summary", alert.get("labels", {}).get("alertname", ""))
    notify_slack(
        (":white_check_mark: *Self-healing executed*" if ok else ":x: *Self-healing FAILED*")
        + f": `kubectl rollout restart deployment/{name}`",
        {
            "Alert": summary,
            "Deployment": f"{namespace}/{name}",
            "Result": f"{status.get('availableReplicas', 0)}/{status.get('replicas', 0)} replicas available"
            if ok else "rollout did not finish in time, human intervention required",
            "Duration": f"{elapsed}s",
        },
    )
    return {"deployment": name, "action": "restarted", "healthy": ok, "seconds": elapsed}


def lambda_handler(event, context):
    if not _authorized(event):
        _event("unauthorized_request")
        return _response(401, {"error": "unauthorized"})

    raw = event.get("body") or "{}"
    if event.get("isBase64Encoded"):
        raw = base64.b64decode(raw).decode()
    payload = json.loads(raw)
    _event("webhook_received", status=payload.get("status"), alerts=len(payload.get("alerts", [])))

    results, seen = [], set()
    for alert in payload.get("alerts", []):
        labels = alert.get("labels", {})
        if alert.get("status") != "firing" or labels.get("selfheal") != "true":
            continue
        name = labels.get("deployment", "")
        namespace = labels.get("namespace", DEFAULT_NAMESPACE)
        if name not in ALLOWED or namespace != DEFAULT_NAMESPACE:
            _event("deployment_not_allowed", deployment=name, namespace=namespace)
            results.append({"deployment": name, "action": "rejected_not_allowed"})
            continue
        if (namespace, name) in seen:
            continue
        seen.add((namespace, name))
        try:
            results.append(heal(namespace, name, alert))
        except urllib.error.HTTPError as e:
            _event("kubernetes_api_error", deployment=name, code=e.code, body=e.read().decode()[:500])
            results.append({"deployment": name, "action": "error", "code": e.code})

    return _response(200, {"results": results})
