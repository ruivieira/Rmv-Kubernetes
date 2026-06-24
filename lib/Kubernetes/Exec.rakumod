=begin pod

=head1 NAME

Kubernetes::Exec - shell execution helpers for Kubernetes scripts

=head1 SYNOPSIS

  use Kubernetes::Exec;

  Kubernetes::Exec::run-live('kubectl', 'apply', '-f', $file) or die "apply failed\n";
  my $name = Kubernetes::Exec::run-query('kubectl', 'get', 'pod', $pod, '-o', 'name');

=head1 DESCRIPTION

Thin wrappers around C<run> for kubectl workflows.
Use C<run-live> when the user should see output, C<run-query> for quiet
jsonpath lookups, C<run-capture> when stdout is needed but stderr should
remain visible, and C<run-silent> for existence checks.

=end pod

unit module Kubernetes::Exec;

#| Run a command with stdout and stderr passed through live.
#
# Returns C<True> when the process exit code is C<0>.
our sub run-live(*@cmd --> Bool) is export {
    run(@cmd).exitcode == 0
}

#| Run a command and capture stdout as a trimmed string.
#
# Stderr passes through live. Returns the captured stdout (may be empty).
our sub run-capture(*@cmd --> Str) is export {
    run(@cmd, :out).out.slurp(:close).trim
}

#| Run a command with stdout and stderr suppressed.
#
# Returns C<True> when the process exit code is C<0>. Use for existence checks.
our sub run-silent(*@cmd --> Bool) is export {
    run(@cmd, :out, :err).exitcode == 0
}

#| Run a command, capture stdout, and suppress stderr.
#
# Returns the captured stdout (trimmed). Use for quiet C<kubectl> jsonpath queries.
our sub run-query(*@cmd --> Str) is export {
    run(@cmd, :out, :err).out.slurp(:close).trim
}
