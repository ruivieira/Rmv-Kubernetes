=begin pod

=head1 NAME

Kubernetes::Client — kubectl binary discovery

=head1 SYNOPSIS

  use Kubernetes::Client;

  my $kubectl = Kubernetes::Client::resolve-kubectl();

=head1 DESCRIPTION

Provides C<resolve-kubectl()>, which resolves the kubectl binary from the
C<KUBECTL> environment variable, falling back to C<'kubectl'>.

=end pod

unit module Kubernetes::Client;

#| Resolve the kubectl binary from C<KUBECTL> env or fall back to C<'kubectl'>.
our sub resolve-kubectl(--> Str) {
    %*ENV<KUBECTL> // 'kubectl'
}
