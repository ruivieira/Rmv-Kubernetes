=begin pod

=head1 NAME

Kubernetes::Resources::Secret — Secret resource with apply/delete and key helpers

=head1 SYNOPSIS

  use Kubernetes::Resources::Secret;
  use Kubernetes::Client;

  my $kubectl = Kubernetes::Client::resolve-kubectl();
  my $secret = Kubernetes::Resources::Secret::Secret.new(
      :name<my-secret>, :namespace<default>,
      :data(%(api-key => 'sk-...')),
  );
  $secret.apply($kubectl);
  $secret.ensure-key($kubectl, :key<api-key>, :from-env('MODEL_API_KEY'));
  $secret.delete($kubectl);

=head1 DESCRIPTION

A C<Secret> resource combining C<NamespacedResource> (apply/delete) with
C<exists()>, C<has-key()>, and idempotent C<ensure-key()> from an env var.

=end pod

unit module Kubernetes::Resources::Secret;

use Kubernetes::Resources::Core;
use Kubernetes::Exec;
use Kubernetes::Log;

#| A Kubernetes Secret with YAML generation from C<%.data> (via C<stringData>).
class Secret does Kubernetes::Resources::Core::NamespacedResource {
    has Hash $.data is rw = {};
    has Hash $.labels is rw = {};

    submethod BUILD(
        Str :$!name!,
        Str :$!namespace!,
        Hash :$data = {},
        Hash :$labels = {},
    ) {
        $!apiVersion = 'v1';
        $!kind       = 'Secret';
        $!data       = $data;
        $!labels     = $labels;
    }

    method kubectl-resource(--> Str) { 'secret' }

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
            @lines.push('stringData:');
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

    #| Return C<True> if the Secret exists (C<kubectl get> exits 0).
    method exists(Str $kubectl --> Bool) {
        Kubernetes::Exec::run-silent($kubectl, 'get', 'secret', $.name, '-n', $.namespace)
    }

    #| Return C<True> if C<.data> contains C<$key> (jsonpath presence check).
    method has-key(Str $kubectl, Str $key --> Bool) {
        my $path = '{.data[' ~ "'" ~ $key ~ "'" ~ ']}';
        Kubernetes::Exec::run-query(
            $kubectl, 'get', 'secret', $.name, '-n', $.namespace,
            '-o', 'jsonpath=' ~ $path,
        ).chars > 0
    }

    #| Idempotent: skip if C<$key> exists; else create from C<$from-env> or die.
    method ensure-key(
        Str  $kubectl,
        Str  :$key!,
        Str  :$from-env!,
        Bool :$dry-run,
    ) {
        if $dry-run {
            log-info "  (dry) would ensure secret '{$.name}' key '$key' in {$.namespace} from $from-env";
            return;
        }

        if self.has-key($kubectl, $key) {
            log-info "  secret '{$.name}' already has key '$key' in {$.namespace}, skipping";
            return;
        }

        my $value = %*ENV{$from-env}
            // die "$from-env env var is not set and secret '{$.name}' lacks key '$key' in {$.namespace}\n";

        $.data{$key} = $value;
        self.apply($kubectl) or die "Failed to apply secret '{$.name}'\n";
        log-ok "  secret '{$.name}' created in {$.namespace}";
    }
}
