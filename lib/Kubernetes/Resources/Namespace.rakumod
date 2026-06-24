=begin pod

=head1 NAME

Kubernetes::Resources::Namespace — cluster-scoped Namespace resource

=head1 SYNOPSIS

  use Kubernetes::Resources::Namespace;

  my $ns = Kubernetes::Resources::Namespace::Namespace.new(:name<my-acceptance-ns>);
  $ns.ensure($oc, :$dry-run);
  $ns.label($oc, 'tenant=true', :$dry-run);
  $ns.unlabel($oc, 'tenant', :$dry-run);
  $ns.delete($oc, :$dry-run);

=head1 DESCRIPTION

A cluster-scoped C<Namespace> resource with lifecycle helpers for acceptance
tests and scripts: C<exists()>, C<ensure()>, C<label()>, C<unlabel()>, and
C<delete()> (with C<--wait=false> for fast teardown).

=end pod

unit module Kubernetes::Resources::Namespace;

use Kubernetes::Resources::Core;
use Kubernetes::Exec;
use Kubernetes::Log;

#| A Kubernetes Namespace (cluster-scoped; C<name> is the namespace string).
class Namespace does Kubernetes::Resources::Core::K8sResource {
    submethod BUILD(Str :$!name!) {
        $!apiVersion = 'v1';
        $!kind       = 'Namespace';
    }

    method kubectl-resource(--> Str) { 'namespace' }

    method to-yaml(--> Str) {
        qq:to/END/.chomp;
        apiVersion: $.apiVersion
        kind: $.kind
        metadata:
          name: $.name
        END
    }

    #| Return C<True> if the namespace exists (C<kubectl get> exits 0).
    method exists(Str $kubectl --> Bool) {
        Kubernetes::Exec::run-silent($kubectl, 'get', 'namespace', $.name)
    }

    #| Create the namespace if it does not already exist.
    method ensure(Str $kubectl, Bool :$dry-run) {
        return if self.exists($kubectl);
        if $dry-run { log-info "  (dry) create namespace {$.name}"; return }
        log-info "Creating namespace {$.name}";
        Kubernetes::Exec::run-live($kubectl, 'create', 'namespace', $.name)
            or die "Failed to create namespace {$.name}\n";
    }

    #| Add C<$label> (C<"key=value"> form) with C<--overwrite>.
    method label(Str $kubectl, Str $label, Bool :$dry-run) {
        if $dry-run { log-info "  (dry) label namespace {$.name} $label"; return }
        Kubernetes::Exec::run-live($kubectl, 'label', 'namespace', $.name, $label, '--overwrite')
            or die "Failed to label namespace {$.name}\n";
    }

    #| Remove label C<$label-key> (trailing C<-> syntax).
    method unlabel(Str $kubectl, Str $label-key, Bool :$dry-run) {
        if $dry-run { log-info "  (dry) unlabel namespace {$.name} $label-key"; return }
        Kubernetes::Exec::run-silent($kubectl, 'label', 'namespace', $.name, "{$label-key}-");
    }

    #| Delete the namespace (C<--ignore-not-found>, C<--wait=false>).
    method delete(Str $kubectl, Bool :$dry-run, Str :$resource = self.kubectl-resource --> Bool) {
        if $dry-run { log-info "  (dry) delete namespace {$.name}"; return True }
        return True unless self.exists($kubectl);
        log-info "Deleting namespace {$.name}";
        Kubernetes::Exec::run-live($kubectl, 'delete', $resource, $.name, '--ignore-not-found', '--wait=false')
    }
}
