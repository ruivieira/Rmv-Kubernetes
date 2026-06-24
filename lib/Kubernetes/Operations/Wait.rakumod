=begin pod

=head1 NAME

Kubernetes::Operations::Wait — phase-polling role for namespaced resources

=head1 SYNOPSIS

  use Kubernetes::Resources::Pod;

  my $pod = Kubernetes::Resources::Pod::Pod.new(:name<my-pod>, :namespace<default>);
  my ($ready, $phase) = $pod.wait-until-ready($kubectl, :timeout-s(120), :interval-s(3));

  # Script-oriented: log, poll, log-ok or log-error + exit:
  $pod.wait-until-ready-or-exit($kubectl, :timeout-s(120));

  # Generic polling (cluster-scoped resources, CSV appearance, …):
  use Kubernetes::Operations::Wait;
  Kubernetes::Operations::Wait::poll-until(now + 300, 5, { ... });

=head1 DESCRIPTION

Provides C<poll-until> for generic deadline polling and C<WaitForReady>, a role
that adds phase-polling to any namespaced resource. The composing class must
supply C<name>, C<namespace>, and C<kubectl-resource()> (all provided by
C<NamespacedResource>).

Override C<ready-phase()> to change the target phase (default: C<'Running'>).

=end pod

unit module Kubernetes::Operations::Wait;

use Kubernetes::Exec;
use Kubernetes::Log;

#| Poll C<&block> every C<$interval-s> seconds until it returns truthy or C<$deadline> passes.
#
# Returns the last value returned by the block (true on success, false on timeout).
our sub poll-until(Instant $deadline, Int $interval-s, &block) {
    loop {
        my $result = block();
        return $result if $result;
        return $result if now >= $deadline;
        sleep $interval-s;
    }
}

#| Adds C<wait-until-ready()> to a C<NamespacedResource>.
#
# Polls C<kubectl get <resource> <name> -n <namespace> -o jsonpath={.status.phase}>
# until the phase matches C<ready-phase()> or the deadline is exceeded.
# Override C<ready-phase()> in the composing class to change the target phase.
role WaitForReady {
    #| The phase string that indicates the resource is ready (default: C<'Running'>).
    method ready-phase(--> Str) { 'Running' }

    #| Human-readable label for log lines (default: C<"{kind}/{name}">).
    method wait-label(--> Str) { "{self.kind}/{self.name}" }

    #| Poll until the resource phase equals C<ready-phase()> or C<$timeout-s> elapses.
    #
    # Returns C<(True, phase)> on success or C<(False, last-phase)> on timeout.
    method wait-until-ready(
        Str $kubectl,
        Int :$timeout-s  = 300,
        Int :$interval-s = 5,
    ) {
        my $deadline = now + $timeout-s;
        my $phase = '';
        my $ok = poll-until($deadline, $interval-s, {
            $phase = Kubernetes::Exec::run-query(
                $kubectl, 'get', self.kubectl-resource, self.name,
                '-n', self.namespace,
                '-o', 'jsonpath={.status.phase}',
            );
            $phase eq self.ready-phase
        });
        ($ok, $phase)
    }

    #| Poll, then log-ok on success or log-error + exit 1 on timeout.
    method wait-until-ready-or-exit(
        Str $kubectl,
        Int :$timeout-s  = 300,
        Int :$interval-s = 5,
    ) {
        log-step "Waiting for {self.wait-label} to reach {self.ready-phase} (timeout: {$timeout-s}s)";
        my ($ok, $phase) = self.wait-until-ready($kubectl, :$timeout-s, :$interval-s);
        unless $ok {
            log-error "{self.wait-label} phase is '{$phase || 'unknown'}' after {$timeout-s}s";
            exit 1;
        }
        log-ok "{self.wait-label} is {self.ready-phase}";
    }
}
