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

my $kubectl = Kubernetes::Client::resolve-kubectl();
say "kubectl: $kubectl";
```

## Cluster preflight

Verify a reachable cluster before applying resources. The cells below require
`kubectl cluster-info` to succeed.

```raku
say run-capture($kubectl, 'cluster-info');
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

## Namespace lifecycle

Create a test namespace, verify it exists, apply a label, remove the label,
then delete it. Names use the document `namePrefix` param and the process ID.
Verification uses `run(...)` so woven output shows real `kubectl` results.

```raku
my $prefix = %params<namePrefix>;
my $ns-name = "{$prefix}-ns-{$*PID}";
my $ns = Kubernetes::Resources::Namespace::Namespace.new(:name($ns-name));

$ns.ensure($kubectl);
say run-capture($kubectl, 'get', 'namespace', $ns-name, '--show-labels');

$ns.label($kubectl, 'rmv-kubernetes=tutorial');
say run-capture($kubectl, 'get', 'namespace', $ns-name, '--show-labels');

$ns.unlabel($kubectl, 'rmv-kubernetes');
say run-capture($kubectl, 'get', 'namespace', $ns-name, '--show-labels');
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
