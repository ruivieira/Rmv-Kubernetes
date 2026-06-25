=begin pod

=head1 NAME

Kubernetes - shared kubectl helpers for Raku scripts

=head1 SYNOPSIS

  use Kubernetes::Resources::Core;

  class Foo does Kubernetes::Resources::Core::NamespacedResource { ... }

  my $ref = Kubernetes::Resources::Core::ResourceRef.new(
      :name<my-sub>, :namespace<ns>, :kubectl-name<subscription>, :kind<Subscription>,
  );
  $ref.delete('kubectl');

  # Pod with wait-until-ready:
  use Kubernetes::Resources::Pod;
  my $pod = Kubernetes::Resources::Pod::Pod.new(:name<my-pod>, :namespace<default>);
  $pod.wait-until-ready('kubectl', :timeout-s(120));

  # ConfigMap apply/delete and data helpers:
  use Kubernetes::Resources::ConfigMap;
  my $cm = Kubernetes::Resources::ConfigMap::ConfigMap.new(
      :name<my-config>, :namespace<default>, :data(%(foo => 'bar')),
  );
  $cm.apply('kubectl');
  $cm.delete('kubectl');

  # Namespace lifecycle:
  use Kubernetes::Resources::Namespace;
  my $ns = Kubernetes::Resources::Namespace::Namespace.new(:name<my-ns>);
  $ns.ensure('kubectl', :dry-run);

=head1 DESCRIPTION

Facade that loads all Kubernetes submodules. Reference symbols via their
fully-qualified submodule names:

=item C<Kubernetes::Resources::Core::K8sResource>
=item C<Kubernetes::Resources::Core::NamespacedResource>
=item C<Kubernetes::Resources::Core::ResourceRef>
=item C<Kubernetes::Resources::Pod::Pod>
=item C<Kubernetes::Resources::ConfigMap::ConfigMap>
=item C<Kubernetes::Resources::Namespace::Namespace>
=item C<Kubernetes::Operations::Wait::WaitForReady>
=item C<Kubernetes::Client::resolve-kubectl()>

=end pod

unit module Kubernetes;

use Kubernetes::Client;
use Kubernetes::Resources::Core;
use Kubernetes::Resources::ConfigMap;
use Kubernetes::Resources::Namespace;
use Kubernetes::Resources::Pod;
use Kubernetes::Operations::Wait;
