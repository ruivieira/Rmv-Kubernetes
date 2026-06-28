---
title: Rmv-Kubernetes Tutorial
params:
  kindCluster: rmv-kubernetes
  namePrefix: rmv-docs
---

## Setup

Load the local library and resolve the kubectl binary.

```raku
use lib 'lib';

use Kubernetes::Client;
use Kubernetes::Exec;
use Kubernetes::Resources::Core;
use Kubernetes::Resources::ConfigMap;
use Kubernetes::Resources::Namespace;
use Kubernetes::Resources::Secret;

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
# Kubernetes control plane is running at https://127.0.0.1:40037
# CoreDNS is running at https://127.0.0.1:40037/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
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
# [INFO]  Creating namespace rmv-docs-ns-192072
# NAME                 STATUS   AGE   LABELS
# rmv-docs-ns-192072   Active   0s    kubernetes.io/metadata.name=rmv-docs-ns-192072
# NAME                 STATUS   AGE   LABELS
# rmv-docs-ns-192072   Active   0s    kubernetes.io/metadata.name=rmv-docs-ns-192072,rmv-kubernetes=tutorial
# NAME                 STATUS   AGE   LABELS
# rmv-docs-ns-192072   Active   1s    kubernetes.io/metadata.name=rmv-docs-ns-192072
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
#       {"apiVersion":"v1","data":{"config":"","greeting":"hello","key":"value"},"kind":"ConfigMap","metadata":{"annotations":{},"name":"rmv-docs-cm-192072","namespace":"rmv-docs-ns-192072"}}
#   creationTimestamp: "2026-06-28T23:35:38Z"
#   name: rmv-docs-cm-192072
#   namespace: rmv-docs-ns-192072
#   resourceVersion: "447"
#   uid: 5a90a709-ffe1-4413-ade2-aeedf37ab790
# Error from server (NotFound): configmaps "rmv-docs-cm-192072" not found
```

## Secret lifecycle

Apply a Secret in the test namespace, confirm it with `kubectl get` (table
output — avoid `-o yaml` here because `.data` values are base64-encoded),
exercise `ensure-key` idempotency, delete it, and confirm removal.

```raku
my $secret-name = "{$prefix}-secret-{$*PID}";
my $secret = Kubernetes::Resources::Secret::Secret.new(
    :name($secret-name), :namespace($ns-name),
    :data(%('api-key' => 'tutorial-key')),
);

$secret.apply($kubectl);
say run-capture($kubectl, 'get', 'secret', $secret-name, '-n', $ns-name);

%*ENV<RMV_K8S_TUTORIAL_SECRET> = 'tutorial-ensure-key';
$secret.ensure-key($kubectl, :key<api-key>, :from-env('RMV_K8S_TUTORIAL_SECRET'));

$secret.delete($kubectl);
my $secret-check = run($kubectl, 'get', 'secret', $secret-name, '-n', $ns-name, :out, :err);
say $secret-check.err.slurp(:close).trim if $secret-check.exitcode != 0;
```
```
# NAME                     TYPE     DATA   AGE
# rmv-docs-secret-192072   Opaque   1      0s
# [INFO]    secret 'rmv-docs-secret-192072' already has key 'api-key' in rmv-docs-ns-192072, skipping
# Error from server (NotFound): secrets "rmv-docs-secret-192072" not found
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
# [INFO]  Deleting namespace rmv-docs-ns-192072
# NAME                 STATUS        AGE
# rmv-docs-ns-192072   Terminating   2s
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
#   namespace: rmv-docs-ns-192072
# True
# [INFO]  Would delete pod/demo-pod in rmv-docs-ns-192072
# True
# Pod polling is available via wait-until-ready($kubectl, :timeout-s(120))
```
