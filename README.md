# Personal Site

Single-page portfolio website built with [Hugo](https://gohugo.io/) (extended) and [TailwindCSS](https://tailwindcss.com/). Deployed as a Docker container (nginx) to a k3s cluster via Helm and SSH tunnel.

## Prerequisites

- [Hugo Extended](https://gohugo.io/installation/) (v0.120+)
- [Node.js](https://nodejs.org/) (v20+)
- [Docker](https://docs.docker.com/get-docker/) (for container builds)
- [Helm](https://helm.sh/) v3.14+ (for k8s deployment)
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (for k8s deployment)

## Quick Start

```bash
# Install dependencies
npm install

# Build TailwindCSS and start dev server
npx @tailwindcss/cli -i ./assets/css/main.css -o ./assets/css/compiled.css --watch &
hugo server -D
```

Open [http://localhost:1313](http://localhost:1313).

## Build for Production

```bash
npx @tailwindcss/cli -i ./assets/css/main.css -o ./assets/css/compiled.css --minify
hugo --minify
```

Output goes to `public/`.

## Docker

```bash
# Build
docker build -t personal-site .

# Run
docker run -p 8080:80 personal-site
```

Open [http://localhost:8080](http://localhost:8080).

## Customizing Content

All content is managed via YAML data files in `data/`:

| File | Content |
|------|---------|
| `data/profile.yaml` | Name, role, bio, links, contact form endpoint |
| `data/projects.yaml` | Featured projects (name, description, repo, tags) |
| `data/experience.yaml` | Work experience (period, role, company, tags) |
| `data/techstack.yaml` | Technology categories and items |
| `data/opensource.yaml` | Open source repositories |

### Contact Form

Set `formEndpoint` in `data/profile.yaml` to enable the contact form:

```yaml
contact:
  formEndpoint: "https://formspree.io/f/your-form-id"
```

Without an endpoint, the form shows a configuration notice.

## Project Structure

```
.
├── assets/css/              # TailwindCSS source (main.css)
├── content/_index.md        # Homepage front matter
├── data/                    # Editable content (YAML)
├── deploy/
│   ├── helm/personal-site/  # Helm chart (deployment, service, ingress)
│   └── nginx/               # Nginx config for Docker image
├── layouts/
│   ├── _default/            # Base and index templates
│   └── partials/            # Section partials (nav, hero, etc.)
├── static/                  # Static assets (favicon, images)
├── .github/workflows/       # CI, Release, Deploy workflows
├── Dockerfile               # Multi-stage build (node → hugo → nginx)
├── hugo.toml                # Hugo configuration
└── package.json             # Node.js / TailwindCSS dependencies
```

## CI/CD

### Workflows

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| **CI** | Push to `main`, PRs | Build site, build Docker image, lint Helm chart |
| **Release** | Push tag `v*.*.*` | Build + push Docker image to GHCR, package + push Helm chart |
| **Deploy** | After Release / manual | Deploy to k3s via SSH tunnel + Helm |

### Release Flow

1. Tag a release: `git tag v1.0.0 && git push origin v1.0.0`
2. Release workflow builds multi-arch Docker image (`linux/amd64,linux/arm64`)
3. Pushes to `ghcr.io/randomtoy/personal-site` with semver tags
4. Packages and pushes Helm chart to `oci://ghcr.io/randomtoy/charts`
5. Deploy workflow triggers automatically on successful Release

### Deployment Architecture

```
GitHub Actions Runner
        │
        ├── SSH tunnel ──→ k3s server (port 6443)
        │       (localhost:16443 → remote:6443)
        │
        └── helm upgrade --install
                via kubectl through tunnel
```

### Required GitHub Secrets

| Secret | Description | Required |
|--------|-------------|----------|
| `SSH_PRIVATE_KEY` | SSH private key for k3s server access | Yes |
| `SSH_HOST` | k3s server hostname or IP | Yes |
| `SSH_USER` | SSH username | Yes |
| `SSH_PORT` | SSH port (default: 22) | No |
| `K8S_API_HOST` | K8s API host from SSH server (default: 127.0.0.1) | No |
| `K8S_API_PORT` | K8s API port (default: 6443) | No |
| `KUBECONFIG_B64` | Base64-encoded kubeconfig | Yes |
| `HELM_NAMESPACE` | Kubernetes namespace (default: personal-site) | No |
| `HELM_RELEASE_NAME` | Helm release name (default: personal-site) | No |
| `HELM_VALUES_B64` | Base64-encoded custom values.yaml | No |

### Getting KUBECONFIG_B64

```bash
# On k3s server
cat /etc/rancher/k3s/k3s.yaml | base64 -w0
```

### Custom Helm Values

Create a `custom-values.yaml`:

```yaml
ingress:
  hosts:
    - host: randomtoy.dev
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: personal-site-tls
      hosts:
        - randomtoy.dev
```

Encode and set as secret:

```bash
cat custom-values.yaml | base64 -w0
# Set the output as HELM_VALUES_B64 secret
```

### Manual Deployment

```bash
# Start SSH tunnel
ssh -N -L 16443:127.0.0.1:6443 user@your-server &

# Patch kubeconfig
export KUBECONFIG=~/.kube/config
sed -E -i "s|(server: https?://)[^:]+:[0-9]+|\1127.0.0.1:16443|g" $KUBECONFIG

# Deploy
helm upgrade --install personal-site deploy/helm/personal-site \
  --namespace personal-site \
  --create-namespace \
  --set image.tag=1.0.0 \
  --wait --timeout 5m --atomic
```

## License

All rights reserved.
