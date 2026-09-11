# opensearch-deploy

OpenSearch + OpenSearch Dashboards for SRE observability: Docker Compose for local development and a Kubernetes deployment for everything else, with an Index State Management (ISM) lifecycle policy that keeps hot data fast and deletes what you no longer need.

## What's in here

| Path | Purpose |
|---|---|
| `docker-compose.yml` | Single-node OpenSearch + Dashboards for local dev, with named volumes |
| `kubernetes/statefulset.yaml` | 3-replica OpenSearch StatefulSet with pod anti-affinity |
| `kubernetes/dashboards-deployment.yaml` | OpenSearch Dashboards deployment + service |
| `kubernetes/ism-policy.json` | ISM policy: hot → warm → delete lifecycle for log indices |
| `dashboards/sre-overview.ndjson` | Sample SRE overview dashboard (index pattern + visualizations) |
| `scripts/bootstrap.sh` | Waits for the cluster to go green, then installs the ISM policy |

## Local development

```bash
docker compose up -d
```

- OpenSearch: http://localhost:9200
- Dashboards: http://localhost:5601

Default credentials are `admin` / `admin` — change them before anything leaves your laptop. The demo security certificates bundled in the image are **not** production-grade; bring your own CA for real deployments.

Data persists in the named volumes `opensearch-data` and `dashboards-data`. Tear it all down with `docker compose down -v`.

## Kubernetes deployment

```bash
kubectl apply -f kubernetes/statefulset.yaml
kubectl apply -f kubernetes/dashboards-deployment.yaml

# Wait for green, then install the ISM lifecycle policy
./scripts/bootstrap.sh
```

The StatefulSet runs 3 replicas with pod anti-affinity so no two data nodes share a host. The ISM policy in `kubernetes/ism-policy.json` attaches to `logs-*` indices: hot for fast ingest, warm after 7 days, deleted after 30 days. Adjust the thresholds for your retention requirements.

`scripts/bootstrap.sh` loops on the cluster health API until status is `green`, then `PUT`s the policy. Set `OPENSEARCH_URL` if your cluster isn't at the default.

## Importing the sample dashboard

`dashboards/sre-overview.ndjson` contains an index pattern plus visualizations for a starter SRE overview dashboard. Import it from the Dashboards UI:

1. Open Dashboards → **Stack Management → Saved Objects**.
2. Click **Import**, select `dashboards/sre-overview.ndjson`.
3. Choose your `logs-*` index pattern when prompted for the data source.

The file is intentionally small — treat it as a scaffold, not a finished product.

## Production notes

- Replace the demo certificates with a real CA (or cert-manager) and rotate the `admin` password into a secret.
- Size `OPENSEARCH_JAVA_OPTS` heap to half of the container memory limit, never above 31 GB.
- The single-node `docker-compose.yml` disables the bootstrap checks that a multi-node cluster needs — don't promote it to production.
