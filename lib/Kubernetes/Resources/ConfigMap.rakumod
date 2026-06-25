=begin pod

=head1 NAME

Kubernetes::Resources::ConfigMap — ConfigMap resource with apply/delete and data helpers

=head1 SYNOPSIS

  use Kubernetes::Resources::ConfigMap;
  use Kubernetes::Client;

  my $kubectl = Kubernetes::Client::resolve-kubectl();
  my $cm = Kubernetes::Resources::ConfigMap::ConfigMap.new(
      :name<my-config>, :namespace<default>,
      :data(%(foo => 'bar', 'app.yaml' => "key: value\n")),
      :labels(%(test => 'true')),
  );
  $cm.apply($kubectl);
  say $cm.get-key($kubectl, 'foo');
  $cm.delete($kubectl);

=head1 DESCRIPTION

A C<ConfigMap> resource combining C<NamespacedResource> (apply/delete) with
C<exists()> and C<get-key()> helpers for reading C<.data> keys from the cluster.

=end pod

unit module Kubernetes::Resources::ConfigMap;

use Kubernetes::Resources::Core;
use Kubernetes::Exec;

#| A Kubernetes ConfigMap with YAML generation from C<%.data>.
class ConfigMap does Kubernetes::Resources::Core::NamespacedResource {
    has Hash $.data is rw = {};
    has Hash $.labels is rw = {};

    submethod BUILD(
        Str :$!name!,
        Str :$!namespace!,
        Hash :$data = {},
        Hash :$labels = {},
    ) {
        $!apiVersion = 'v1';
        $!kind       = 'ConfigMap';
        $!data       = $data;
        $!labels     = $labels;
    }

    method kubectl-resource(--> Str) { 'configmap' }

    method to-yaml(--> Str) {
        my @lines = qq:to/END/.lines;
        apiVersion: $.apiVersion
        kind: $.kind
        metadata:
          name: $.name
          namespace: $.namespace
        END

        if $.labels {
            @lines.push('  labels:');
            for $.labels.sort -> $pair {
                @lines.push("    {$pair.key}: {$pair.value}");
            }
        }

        if $.data {
            @lines.push('data:');
            for $.data.sort -> $pair {
                my $yaml-key = $pair.key ~~ / <-[ \w - ] > /
                    ?? '"' ~ $pair.key ~ '"'
                    !! $pair.key;
                if $pair.value.contains("\n") {
                    @lines.push("  $yaml-key: |");
                    @lines.append($pair.value.lines.map("  " ~ *));
                } else {
                    @lines.push("  $yaml-key: {$pair.value}");
                }
            }
        }

        @lines.join("\n")
    }

    #| Return C<True> if the ConfigMap exists (C<kubectl get> exits 0).
    method exists(Str $kubectl --> Bool) {
        Kubernetes::Exec::run-silent($kubectl, 'get', 'configmap', $.name, '-n', $.namespace)
    }

    #| Fetch a C<.data> key via kubectl template.
    method get-key(Str $kubectl, Str $key --> Str) {
        Kubernetes::Exec::run-query(
            $kubectl, 'get', 'configmap', $.name, '-n', $.namespace,
            '--template', '{{index .data "' ~ $key ~ '"}}',
        )
    }
}
