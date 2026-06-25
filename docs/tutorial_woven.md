---
title: Rmv-Kubernetes Tutorial
params:
  kindCluster: rmv-kubernetes
  namePrefix: rmv-docs
---

# Rmv-Kubernetes Tutorial

This tutorial walks through the `Kubernetes:auth<zef:rmv>` library using
[Text::CodeProcessing](https://raku.land/zef:antononcube/Text::CodeProcessing)
literate programming. Code cells run sequentially in a single REPL session —
variables and loaded modules persist across cells.

Resource names use the `rmv-docs` prefix (from document params) and `$*PID` for
uniqueness against a shared KinD cluster (`rmv-kubernetes`).

## Prerequisites

- **Raku** with `zef`
- **`kubectl`** on PATH (or set `KUBECTL`)
- **`kind`** for live-cluster examples
- **`Text::CodeProcessing`** — install with `make docs-deps` or
  `zef install Text::CodeProcessing`

Run the full pipeline (create KinD cluster, weave this document, delete cluster):

```bash
make docs-kind
```

Manual weave against an existing cluster:

```bash
make docs-deps
make docs-weave
```

## Setup

Load the local library and resolve the kubectl binary.

```raku
use lib 'lib';

use Kubernetes::Client;
use Kubernetes::Exec;
use Kubernetes::Resources::Core;
use Kubernetes::Resources::ConfigMap;
use Kubernetes::Resources::Namespace;

my $kubectl = Kubernetes::Client::resolve-kubectl();
say "kubectl: $kubectl";
```
```
# kubectl: kubectl
```

## Cluster preflight

Verify a reachable cluster before applying resources. The cells below require
`kubectl cluster-info` to succeed.

```raku
say run-capture($kubectl, 'cluster-info');
```
```
# Kubernetes control plane is running at https://127.0.0.1:40179
# CoreDNS is running at https://127.0.0.1:40179/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
# 
# To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

## Dry-run without a cluster

Custom resources can exercise apply/delete paths with `:dry-run` — no cluster
mutation. This mirrors the unit tests in `t/01-kubernetes.rakutest`.

```raku
my class DemoResource does Kubernetes::Resources::Core::K8sResource {
    submethod BUILD(Str :$!name!) {
        $!apiVersion = 'example/v1';
        $!kind = 'Demo';
    }
    method to-yaml(--> Str) { "kind: Demo\nname: $.name\n" }
}

my $demo = DemoResource.new(:name<dry-run-demo>);
say $demo.apply($kubectl, :dry-run);
say $demo.delete($kubectl, :dry-run);
```
```
# kind: Demo
# name: dry-run-demo
# 
# True
# [INFO]  Would delete demo/dry-run-demo
# True
```

## Namespace lifecycle

Create a test namespace, verify it exists, apply a label, remove the label,
then delete it. Names use the document `namePrefix` param and the process ID.
Verification uses `run(...)` so woven output shows real `kubectl` results.

```raku
my $prefix = 'rmv-docs';
my $ns-name = "{$prefix}-ns-{$*PID}";
my $ns = Kubernetes::Resources::Namespace::Namespace.new(:name($ns-name));

$ns.ensure($kubectl);
say run-capture($kubectl, 'get', 'namespace', $ns-name, '--show-labels');

$ns.label($kubectl, 'rmv-kubernetes=tutorial');
say run-capture($kubectl, 'get', 'namespace', $ns-name, '--show-labels');

$ns.unlabel($kubectl, 'rmv-kubernetes');
say run-capture($kubectl, 'get', 'namespace', $ns-name, '--show-labels');
```
```
# [INFO]  Creating namespace rmv-docs-ns-254666
# NAME                 STATUS   AGE   LABELS
# rmv-docs-ns-254666   Active   1s    kubernetes.io/metadata.name=rmv-docs-ns-254666
# NAME                 STATUS   AGE   LABELS
# rmv-docs-ns-254666   Active   1s    kubernetes.io/metadata.name=rmv-docs-ns-254666,rmv-kubernetes=tutorial
# NAME                 STATUS   AGE   LABELS
# rmv-docs-ns-254666   Active   2s    kubernetes.io/metadata.name=rmv-docs-ns-254666
```

## ConfigMap lifecycle

Apply a ConfigMap in the test namespace, inspect it with `kubectl`, delete it,
and confirm removal via `kubectl get`.

```raku
my $cm-name = "{$prefix}-cm-{$*PID}";
my $cm = Kubernetes::Resources::ConfigMap::ConfigMap.new(
    :name($cm-name), :namespace($ns-name),
    :data(%(greeting => 'hello', config => "key: value\n")),
);

$cm.apply($kubectl);
say run-capture($kubectl, 'get', 'configmap', $cm-name, '-n', $ns-name, '-o', 'yaml');

$cm.delete($kubectl);
my $cm-check = run($kubectl, 'get', 'configmap', $cm-name, '-n', $ns-name, :out, :err);
say $cm-check.err.slurp(:close).trim if $cm-check.exitcode != 0;
```
```
# apiVersion: v1
# data:
#   config: ""
#   greeting: hello
#   key: value
# kind: ConfigMap
# metadata:
#   annotations:
#     kubectl.kubernetes.io/last-applied-configuration: |
#       {"apiVersion":"v1","data":{"config":"","greeting":"hello","key":"value"},"kind":"ConfigMap","metadata":{"annotations":{},"name":"rmv-docs-cm-254666","namespace":"rmv-docs-ns-254666"}}
#   creationTimestamp: "2026-06-25T20:02:18Z"
#   name: rmv-docs-cm-254666
#   namespace: rmv-docs-ns-254666
#   resourceVersion: "445"
#   uid: 3fcdc566-1995-43cb-b9a5-c1be1b7ac406
# Error from server (NotFound): configmaps "rmv-docs-cm-254666" not found
```

## Cleanup

Remove the test namespace and confirm with `kubectl get`.

```raku
$ns.delete($kubectl);
my $ns-check = run($kubectl, 'get', 'namespace', $ns-name, :out, :err);
if $ns-check.exitcode == 0 {
    say $ns-check.out.slurp(:close).trim;
} else {
    say $ns-check.err.slurp(:close).trim;
}
```
```
# [INFO]  Deleting namespace rmv-docs-ns-254666
# NAME                 STATUS        AGE
# rmv-docs-ns-254666   Terminating   2s
```

## Pod polling (dry-run only)

`Kubernetes::Resources::Pod` combines manifest apply/delete with
`wait-until-ready` polling. The built-in `to-yaml` emits metadata only (no
container spec), so live apply on KinD would fail. Use dry-run to verify the
API surface:

```raku
use Kubernetes::Resources::Pod;

my $pod = Kubernetes::Resources::Pod::Pod.new(
    :name<demo-pod>, :namespace($ns-name),
);
say $pod.apply($kubectl, :dry-run);
say $pod.delete($kubectl, :dry-run);
say 'Pod polling is available via wait-until-ready($kubectl, :timeout-s(120))';
```
```
# apiVersion: v1
# kind: Pod
# metadata:
#   name: demo-pod
#   namespace: rmv-docs-ns-254666
# True
# [INFO]  Would delete pod/demo-pod in rmv-docs-ns-254666
# True
# Pod polling is available via wait-until-ready($kubectl, :timeout-s(120))
```
