=begin pod

=head1 NAME

Kubernetes::Resources::Core — base roles and lightweight handles for K8s CRs

=head1 SYNOPSIS

  use Kubernetes::Resources::Core;

  class Foo does Kubernetes::Resources::Core::NamespacedResource {
      submethod BUILD(Str :$!name!, Str :$!namespace!) { $!apiVersion = 'v1'; $!kind = 'Foo' }
      method to-yaml(--> Str) { ... }
  }

=head1 DESCRIPTION

=item C<K8sResource> — common metadata for cluster-scoped CRs (C<apiVersion>,
C<kind>, C<name>, C<to-yaml()>, C<apply()>, C<delete()>)

=item C<NamespacedResource> — extends C<K8sResource> with a required C<namespace>

=item C<ResourceRef> — lightweight namespaced handle when no manifest class
exists (e.g. OLM C<Subscription>)

=end pod

unit module Kubernetes::Resources::Core;

use Kubernetes::Exec;
use Kubernetes::Log;

#| Common metadata for any Kubernetes / OpenShift CR or resource.
role K8sResource {
    has Str $.apiVersion is required;
    has Str $.kind       is required;
    has Str $.name       is required where *.chars > 0;

    #| Serialise this resource to a YAML string.
    method to-yaml(--> Str) { die "to-yaml must be implemented by class" }

    #| kubectl resource name used by C<delete()> (defaults to lowercased C<kind>).
    method kubectl-resource(--> Str) { $.kind.lc }

    #| Run C<kubectl delete> for this cluster-scoped resource.
    method delete(Str $kubectl, Bool :$dry-run, Str :$resource = self.kubectl-resource --> Bool) {
        if $dry-run {
            log-info "Would delete $resource/{$.name}";
            return True;
        }
        Kubernetes::Exec::run-live($kubectl, 'delete', $resource, $.name, '--ignore-not-found')
    }

    #| Write C<to-yaml()> output to a temp file and run C<kubectl apply -f>.
    method apply(Str $kubectl, Bool :$dry-run --> Bool) {
        if $dry-run {
            say self.to-yaml;
            return True;
        }
        my $path = "/tmp/kubernetes-{$*PID}-{$.name}.yaml";
        {
            LEAVE { $path.IO.unlink if $path.IO.e }
            $path.IO.spurt(self.to-yaml);
            return Kubernetes::Exec::run-live($kubectl, 'apply', '-f', $path);
        }
    }
}

#| Namespaced resources (ImageStream, BuildConfig, …).
role NamespacedResource does K8sResource {
    has Str $.namespace is required where *.chars > 0;

    #| Run C<kubectl delete -n> for this namespaced resource.
    method delete(Str $kubectl, Bool :$dry-run, Str :$resource = self.kubectl-resource --> Bool) {
        if $dry-run {
            log-info "Would delete $resource/{$.name} in {$.namespace}";
            return True;
        }
        Kubernetes::Exec::run-live($kubectl, 'delete', $resource, $.name, '-n', $.namespace, '--ignore-not-found')
    }
}

#| Namespaced kubectl target when no manifest class exists (e.g. OLM Subscription).
class ResourceRef does NamespacedResource {
    has Str $.kubectl-name is required where *.chars > 0;

    submethod BUILD(
        Str :$!name!,
        Str :$!namespace!,
        Str :$!kubectl-name!,
        Str :$!kind!,
    ) {
        $!apiVersion = 'meta/v1';
    }

    method kubectl-resource(--> Str) { $.kubectl-name }

    method to-yaml(--> Str) { die "ResourceRef is for kubectl delete only" }
}
