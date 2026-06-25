=begin pod

=head1 NAME

Kubernetes::Log - ANSI-colored log helpers for Kubernetes scripts

=head1 SYNOPSIS

  use Kubernetes::Log;
  log-step "Phase 1: ensuring manifest volume";
  log-info "Found pod: $pod";
  log-ok "Operator pod ready";

=head1 DESCRIPTION

Consistent terminal output with severity prefixes. Each C<log-*> sub writes
one line to stdout with bold color-coded tags.

=end pod

unit module Kubernetes::Log;

my constant RESET  = "\e[0m";
my constant BOLD   = "\e[1m";
my constant BLUE   = "\e[34m";
my constant GREEN  = "\e[32m";
my constant YELLOW = "\e[33m";
my constant RED    = "\e[31m";
my constant CYAN   = "\e[36m";
my constant MAGENTA = "\e[35m";

#| True when ANSI styling is allowed (respects https://no-color.org/).
my sub color-enabled(--> Bool) {
    return True unless %*ENV<NO_COLOR>:exists;
    my $v = %*ENV<NO_COLOR>.lc.trim;
    return True if $v eq '' || $v ~~ / ^ ['0' | false | no] $ /;
    False
}

my sub ansi(Str $code --> Str) { color-enabled() ?? $code !! '' }

#| Informational message (blue C<[INFO]> tag).
sub log-info(Str $msg)  is export { say "{ansi(BOLD)}{ansi(BLUE)}[INFO]{ansi(RESET)}  $msg" }

#| Success message (green C<[ OK ]> tag).
sub log-ok(Str $msg)    is export { say "{ansi(BOLD)}{ansi(GREEN)}[ OK ]{ansi(RESET)}  $msg" }

#| Non-fatal warning (yellow C<[WARN]> tag).
sub log-warn(Str $msg)  is export { say "{ansi(BOLD)}{ansi(YELLOW)}[WARN]{ansi(RESET)}  $msg" }

#| Failure message (red C<[FAIL]> tag); does not exit — caller decides.
sub log-error(Str $msg) is export { say "{ansi(BOLD)}{ansi(RED)}[FAIL]{ansi(RESET)}  $msg" }

#| Phase or step banner (cyan C<[>>>>]> tag).
sub log-step(Str $msg)  is export { say "{ansi(BOLD)}{ansi(CYAN)}[>>>>]{ansi(RESET)}  $msg" }

#| Completion banner (magenta C<[DONE]> tag).
sub log-done(Str $msg)  is export { say "{ansi(BOLD)}{ansi(MAGENTA)}[DONE]{ansi(RESET)}  $msg" }
