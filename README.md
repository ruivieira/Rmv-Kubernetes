# Kubernetes

[![CI](https://github.com/ruivieira/Rmv-Kubernetes/actions/workflows/test.yml/badge.svg)](https://github.com/ruivieira/Rmv-Kubernetes/actions/workflows/test.yml)
[![version](https://img.shields.io/badge/version-v0.0.3-blue)](https://github.com/ruivieira/Rmv-Kubernetes/blob/main/META6.json)
[![License](https://img.shields.io/badge/License-Apache--2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Raku kubectl helpers for Kubernetes and OpenShift workflows.

**Distribution:** `Kubernetes:auth<zef:rmv>`  
**Repository:** [Rmv-Kubernetes](https://github.com/ruivieira/Rmv-Kubernetes)  
**Tutorial:** [`docs/tutorial_woven.md`](docs/tutorial_woven.md)

## Synopsis

```raku
use Kubernetes::Resources::ConfigMap;
use Kubernetes::Resources::Namespace;
use Kubernetes::Client;

my $kubectl = Kubernetes::Client::resolve-kubectl();

# ConfigMap apply/delete and data helpers
my $cm = Kubernetes::Resources::ConfigMap::ConfigMap.new(
    :name<my-config>, :namespace<default>,
    :data(%(foo => 'bar', 'app.yaml' => "key: value\n")),
);
$cm.apply($kubectl);
say $cm.get-key($kubectl, 'foo');
$cm.delete($kubectl);

# Namespace lifecycle
my $ns = Kubernetes::Resources::Namespace::Namespace.new(:name<my-ns>);
$ns.ensure($kubectl);
$ns.label($kubectl, 'tenant=true');
$ns.delete($kubectl);

# Lightweight handle for resources without a manifest class
my $ref = Kubernetes::Resources::Core::ResourceRef.new(
    :name<my-sub>, :namespace<my-namespace>,
    :kubectl-name<subscription>, :kind<Subscription>,
);
$ref.delete($kubectl);

# Poll until a pod reaches Running
use Kubernetes::Resources::Pod;
my $pod = Kubernetes::Resources::Pod::Pod.new(:name<my-pod>, :namespace<default>);
my ($ready, $phase) = $pod.wait-until-ready($kubectl, :timeout-s(120));
```

## Installation

From zef:

```bash
zef install 'Kubernetes:auth<zef:rmv>'
```

Local development:

```bash
git clone https://github.com/ruivieira/Rmv-Kubernetes.git
cd Rmv-Kubernetes
zef install --force-install .
```

Requires `kubectl` (or set `KUBECTL` to an alternate binary path).

## Modules

| Module | Purpose |
|--------|---------|
| `Kubernetes::Client` | Resolve kubectl binary (`KUBECTL` env or `kubectl`) |
| `Kubernetes::Exec` | Shell execution helpers (`run-live`, `run-query`, …) |
| `Kubernetes::Log` | ANSI-colored log output (`log-info`, `log-step`, …) |
| `Kubernetes::Resources::Core` | Base roles `K8sResource`, `NamespacedResource`; `ResourceRef` class |
| `Kubernetes::Resources::ConfigMap` | ConfigMap apply/delete, YAML from `data`, `exists`, `get-key` |
| `Kubernetes::Resources::Namespace` | Namespace create/label/delete lifecycle |
| `Kubernetes::Resources::Pod` | Pod resource with `WaitForReady` polling |
| `Kubernetes::Operations::Wait` | `poll-until` and `WaitForReady` role |

## Development

```bash
make check        # syntax-check all .rakumod files
make unit         # unit tests (dry-run, no cluster)
make integration  # integration tests (requires KUBECONFIG / KinD)
make lint         # style checks (trailing whitespace, tabs, …)
make secrets      # gitleaks scan
make pre-commit   # run all pre-commit hooks
make all          # check + lint + unit + secrets
make docs-kind    # KinD cluster + weave literate tutorial + teardown
make docs         # weave docs/tutorial.md (requires cluster for weave)
make docs-weave   # evaluate code cells → docs/tutorial_woven.md
```

Install git hooks:

```bash
pre-commit install
```

## Testing

**Unit tests** (`t/*.rakutest`) exercise roles and dry-run paths without a live cluster.

**Integration tests** (`t/integration/*.rakutest`) run against a reachable cluster. They skip when `kubectl cluster-info` fails (no kubeconfig or cluster unavailable).

Local KinD example:

```bash
kind create cluster
make integration
kind delete cluster
```

## Documentation

[`docs/tutorial_woven.md`](docs/tutorial_woven.md) — tutorial with evaluated Raku cells and live `kubectl` output. Source: [`docs/tutorial.md`](docs/tutorial.md) (`make docs-weave` to regenerate).

## CI

GitHub Actions runs two jobs on every push and pull request:

| Job | What it runs |
|-----|--------------|
| **unit** | `make unit` |
| **integration** | KinD cluster + `kubectl cluster-info` + `make integration` |

## License

Apache-2.0
