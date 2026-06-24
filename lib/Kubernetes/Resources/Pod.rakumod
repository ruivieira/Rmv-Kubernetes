=begin pod

=head1 NAME

Kubernetes::Resources::Pod — Pod resource with readiness polling

=head1 SYNOPSIS

  use Kubernetes::Resources::Pod;
  use Kubernetes::Client;

  my $kubectl = Kubernetes::Client::resolve-kubectl();
  my $pod = Kubernetes::Resources::Pod::Pod.new(:name<my-pod>, :namespace<default>);

  my ($ready, $phase) = $pod.wait-until-ready($kubectl, :timeout-s(120));
  if $ready {
      say "Pod is $phase";
  }

=head1 DESCRIPTION

A C<Pod> resource combining C<NamespacedResource> (apply/delete) with
C<WaitForReady> (phase polling). Polls C<status.phase eq 'Running'>.

=end pod

unit module Kubernetes::Resources::Pod;

use Kubernetes::Resources::Core;
use Kubernetes::Operations::Wait;

#| A Kubernetes Pod with phase-polling via C<wait-until-ready()>.
class Pod
    does Kubernetes::Resources::Core::NamespacedResource
    does Kubernetes::Operations::Wait::WaitForReady
{
    submethod BUILD(Str :$!name!, Str :$!namespace!) {
        $!apiVersion = 'v1';
        $!kind       = 'Pod';
    }

    method to-yaml(--> Str) {
        qq:to/END/.chomp;
        apiVersion: $.apiVersion
        kind: $.kind
        metadata:
          name: $.name
          namespace: $.namespace
        END
    }
}
