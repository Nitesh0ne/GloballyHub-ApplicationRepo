# Vendure DevOps Assignment

Production-oriented deployment of a Vendure e-commerce application using Docker, Kubernetes, Helm, GitHub Actions, GitHub Container Registry (GHCR), and Argo CD.

The project demonstrates a GitOps-based application delivery workflow with Kubernetes health checks, persistent PostgreSQL storage, containerized application deployment, and automated CI.

---

## Architecture

```text
Developer
   |
   | git push
   v
GitHub Repository
   |
   v
GitHub Actions
   |
   +--> npm ci
   +--> npm run build
   +--> Docker build
   +--> Push image to GHCR
   |
   v
GitHub Container Registry
   |
   v
Argo CD
   |
   | GitOps reconciliation
   v
Helm
   |
   v
Kubernetes
   |
   +--> NGINX Ingress
   |
   +--> Vendure Service :3000
   |       |
   |       v
   |    Vendure Pod
   |
   +--> PostgreSQL Service :5432
           |
           v
        PostgreSQL Pod
           |
           v
        2 GiB PVC
```

---

# Technology Stack

| Component | Technology |
|---|---|
| Application | Vendure |
| Runtime | Node.js 20 |
| Language | TypeScript |
| Database | PostgreSQL 16 |
| Containerization | Docker |
| Container Registry | GitHub Container Registry |
| CI | GitHub Actions |
| Orchestration | Kubernetes |
| Kubernetes Distribution | kind |
| Package Management | Helm |
| Ingress | NGINX Ingress Controller |
| GitOps | Argo CD |
| Storage | Kubernetes PersistentVolumeClaim |
| Source Control | Git / GitHub |

---

# Project Structure

```text
vendure-devops-project/
├── .github/
│   └── workflows/
│       └── ci.yml
├── helm/
│   └── vendure/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── _helpers.tpl
│           ├── configmap.yaml
│           ├── deployment.yaml
│           ├── ingress.yaml
│           ├── namespace.yaml
│           ├── postgres-deployment.yaml
│           ├── postgres-pvc.yaml
│           ├── postgres-service.yaml
│           ├── secret.yaml
│           └── service.yaml
├── k8s/
│   ├── configmap.yaml
│   ├── deployment.yaml
│   ├── namespace.yaml
│   ├── postgres-deployment.yaml
│   ├── postgres-service.yaml
│   ├── secret.example.yaml
│   └── service.yaml
├── src/
├── Dockerfile
├── docker-compose.yml
├── package.json
├── package-lock.json
└── README.md
```

---

# Docker Image

The application uses a multi-stage Docker build.

## Builder Stage

The builder stage:

1. Uses Node.js 20.
2. Installs dependencies using `npm ci`.
3. Copies application source.
4. Builds the application using `npm run build`.

## Runtime Stage

The runtime stage:

1. Uses a clean Node.js 20 image.
2. Installs only production dependencies.
3. Copies the compiled application.
4. Runs the application as the non-root `node` user.

The container starts with:

```bash
node ./dist/index.js
```

### Security consideration

The application does not run as root inside the container:

```dockerfile
USER node
```

---

# CI Pipeline

The CI pipeline is defined in:

```text
.github/workflows/ci.yml
```

The workflow runs on:

- Pushes to `main`
- Pull requests targeting `main`

## Pipeline Flow

```text
Git Push
   |
   v
Checkout
   |
   v
Setup Node.js 20
   |
   v
npm ci
   |
   v
npm run build
   |
   v
Docker Build
   |
   v
Push image to GHCR
```

The workflow uses:

- `actions/checkout`
- `actions/setup-node`
- `docker/login-action`
- `docker/metadata-action`
- `docker/build-push-action`

Container registry:

```text
ghcr.io
```

Image repository:

```text
ghcr.io/nitesh0ne/vendure-devops-project
```

---

# Kubernetes Deployment

The application is deployed to Kubernetes using Helm.

Current environment:

```text
Kubernetes Server: v1.33.1
Node: vendure-control-plane
Distribution: kind
```

## Namespace

The application runs inside:

```text
vendure
```

---

# Kubernetes Components

## Vendure Deployment

The Helm deployment creates a Vendure Deployment with:

```text
Replica Count: 1
Container Port: 3000
```

Resource requests:

```yaml
cpu: 250m
memory: 512Mi
```

Resource limits:

```yaml
cpu: 1
memory: 1Gi
```

## Vendure Service

The application is exposed internally through a Kubernetes `ClusterIP` service:

```text
Service: vendure-vendure
Port: 3000
```

Traffic flow:

```text
Ingress
   |
   v
vendure-vendure:3000
   |
   v
Vendure Pod
```

---

# PostgreSQL

PostgreSQL runs as a separate Kubernetes Deployment:

```text
Image: postgres:16-alpine
Port: 5432
```

It is exposed internally through:

```text
vendure-vendure-postgres:5432
```

The database is not directly exposed externally.

---

# Persistent Storage

PostgreSQL uses a Kubernetes PersistentVolumeClaim.

Current configuration:

```text
PVC: vendure-vendure-postgres
Capacity: 2Gi
Access Mode: RWO
StorageClass: standard
Status: Bound
```

This keeps PostgreSQL data outside the lifecycle of the database container.

---

# Health Checks

Vendure exposes:

```text
/health
```

Kubernetes uses this endpoint for readiness and liveness checks.

## Readiness Probe

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: http
```

The readiness probe determines whether the application is ready to receive traffic.

## Liveness Probe

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: http
```

The liveness probe allows Kubernetes to detect an unhealthy application and restart the container when necessary.

---

# Ingress

The application uses the NGINX Ingress Controller.

Current configuration:

```text
Ingress Class: nginx
Host: vendure.local
Port: 80
Path: /
```

Traffic flow:

```text
HTTP Request
     |
     v
NGINX Ingress Controller
     |
     v
Vendure Service
     |
     v
Vendure Pod
```

TLS/SSL configuration is intentionally outside the scope of this assignment.

---

# Helm

The Kubernetes resources are packaged using Helm.

Chart location:

```text
helm/vendure
```

The chart manages:

- Namespace
- Vendure Deployment
- Vendure Service
- PostgreSQL Deployment
- PostgreSQL Service
- PostgreSQL PVC
- ConfigMap
- Secret reference
- Ingress

## Helm Validation

```bash
helm lint helm/vendure
```

Result:

```text
1 chart(s) linted, 0 chart(s) failed
```

Template rendering:

```bash
helm template vendure helm/vendure
```

Result:

```text
exit code: 0
```

---

# GitOps with Argo CD

Argo CD manages the Kubernetes deployment.

Application:

```text
vendure
```

Repository:

```text
https://github.com/Nitesh0ne/vendure-devops-project.git
```

Branch:

```text
main
```

Helm path:

```text
helm/vendure
```

Current status:

```text
SYNC STATUS:   Synced
HEALTH STATUS: Healthy
```

This means Argo CD successfully reconciles the Kubernetes resources with the Git repository.

---

# Deployment Flow

```text
Developer
    |
    | git push
    v
GitHub
    |
    v
GitHub Actions
    |
    +--> npm ci
    +--> npm run build
    +--> Docker build
    +--> Push image to GHCR
    |
    v
Git Repository
    |
    v
Argo CD
    |
    v
Helm
    |
    v
Kubernetes
    |
    +--> Vendure
    +--> PostgreSQL
    +--> Persistent Storage
    +--> NGINX Ingress
```

---

# Verification

The deployment was verified using Kubernetes, Helm, Argo CD, Git, and external HTTP checks.

## Kubernetes

```bash
kubectl get nodes
```

Expected:

```text
vendure-control-plane   Ready
```

## Application

```bash
kubectl get pods -n vendure
```

Current state:

```text
vendure-vendure-*             1/1   Running
vendure-vendure-postgres-*    1/1   Running
```

## Storage

```bash
kubectl get pvc -n vendure
```

Current state:

```text
STATUS: Bound
CAPACITY: 2Gi
```

## Ingress

```bash
kubectl get ingress -n vendure
```

Current configuration:

```text
CLASS: nginx
HOST: vendure.local
PORT: 80
```

## Argo CD

```bash
kubectl get application vendure -n argocd
```

Current state:

```text
SYNC STATUS: Synced
HEALTH STATUS: Healthy
```

## Helm

```bash
helm lint helm/vendure
```

Result:

```text
0 chart(s) failed
```

## Application Health

The application was externally tested using:

```bash
curl -H "Host: vendure.local" http://<EC2_PUBLIC_IP>/health
```

Response:

```json
{"status":"ok"}
```

HTTP response:

```text
HTTP/1.1 200 OK
```

---

# Configuration and Secrets

Application configuration is stored using Kubernetes ConfigMaps.

Sensitive values are stored using Kubernetes Secrets.

The Helm chart supports an externally managed Secret:

```yaml
secrets:
  create: false
  name: vendure-vendure-secret
```

This prevents sensitive credentials from being generated directly by the Helm chart.

Production credentials are not stored in the Git repository.

---

# Security Considerations

The deployment includes:

- Multi-stage Docker build
- Production-only dependencies in the runtime image
- Non-root container execution
- Kubernetes Secrets for sensitive configuration
- PostgreSQL exposed only through an internal ClusterIP service
- Resource requests and limits
- Readiness probes
- Liveness probes
- Persistent database storage
- Restricted GitHub Actions permissions

---

# Operational Commands

## Check application

```bash
kubectl get pods -n vendure
```

## Check services

```bash
kubectl get svc -n vendure
```

## Check storage

```bash
kubectl get pvc -n vendure
```

## Check ingress

```bash
kubectl get ingress -n vendure
```

## Check Argo CD

```bash
kubectl get application vendure -n argocd
```

## Check application logs

```bash
kubectl logs -n vendure deployment/vendure-vendure
```

## Check PostgreSQL logs

```bash
kubectl logs -n vendure deployment/vendure-vendure-postgres
```

## Check Helm

```bash
helm lint helm/vendure
```

## Render Helm templates

```bash
helm template vendure helm/vendure
```

## Check Git state

```bash
git status
```

---

# Current Deployment Status

| Component | Status |
|---|---|
| Git Repository | Healthy |
| Git Working Tree | Clean |
| GitHub Actions | Configured |
| Docker Build | Configured |
| GHCR | Configured |
| Kubernetes Node | Ready |
| Vendure Pod | Running |
| PostgreSQL Pod | Running |
| PostgreSQL PVC | Bound |
| NGINX Ingress | Running |
| Argo CD | Synced / Healthy |
| Helm Lint | Passed |
| Helm Template | Passed |
| `/health` Endpoint | HTTP 200 |
| Domain / TLS | Out of Scope |

---

# Known Limitation

The current CI pipeline publishes the Docker image using the `latest` tag:

```yaml
tag: latest
```

Kubernetes also uses:

```yaml
imagePullPolicy: IfNotPresent
```

For a production-grade deployment, immutable image tags such as Git commit SHA should be preferred.

A future improvement would be:

```text
Git Commit SHA
      |
      v
Docker Image
      |
      v
GHCR
      |
      v
Update Helm image tag
      |
      v
Argo CD
      |
      v
Kubernetes rollout
```

This prevents ambiguity around the `latest` tag and makes deployments reproducible.

---

# Future Improvements

Possible improvements include:

- Immutable Docker image tags
- Automated image tag updates
- Horizontal Pod Autoscaling
- NetworkPolicies
- PodDisruptionBudgets
- Separate production and staging environments
- External managed PostgreSQL
- Centralized logging
- Prometheus/Grafana monitoring
- Container image vulnerability scanning
- Kubernetes security scanning
- TLS/HTTPS
- DNS configuration
- External secrets management
- Backup and restore strategy

---

# Conclusion

This project demonstrates a complete containerized application deployment workflow using modern DevOps and GitOps practices.

The application is:

- Containerized using Docker
- Built automatically using GitHub Actions
- Stored in GitHub Container Registry
- Packaged using Helm
- Deployed to Kubernetes
- Exposed through NGINX Ingress
- Managed through Argo CD
- Backed by persistent PostgreSQL storage
- Protected by Kubernetes health checks
- Validated through automated and manual operational checks
