package App::ProveAuthor;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use App::ProveDists ();
use Hash::Subset qw(hash_subset);

our %SPEC;

$SPEC{prove_author} = {
    v => 1.1,
    summary => "Prove distributions of a CPAN author",
    description => <<'_',

To use this utility, first create `~/.config/prove-author.conf`:

    dists_dirs = ~/repos
    dists_dirs = ~/repos-other

The above tells *prove-author* where to look for Perl distributions. Then:

    % prove-author PERLANCAR

This will search local CPAN mirror for all distributions that belong to that
author, then search the distributions in the distribution directories (or
download them from local CPAN mirror), `cd` to each and run `prove` in it.

You can run with `--dry-run` (`-n`) option first to not actually run `prove` but
just see what distributions will get tested. An example output:

    % prove-author GRAVATTJ -n
    prove-author: Found dist: Backup-Duplicity-YADW
    prove-author: Found dist: Backup-EZ
    prove-author: Found dist: CLI-Driver
    prove-author: Found dist: File-RandomGenerator
    prove-author: Found dist: MySQL-ORM
    prove-author: Found dist: MySQL-QueryMulti
    prove-author: Found dist: MySQL-Util
    prove-author: Found dist: MySQL-Util-Lite-ForeignKeyColumn
    prove-author: Found dist: Util-Medley
    prove-author: Found dist: Backup-Duplicity-YADW
    prove-author: Found dist: Backup-EZ
    prove-author: Found dist: CLI-Driver
    prove-author: Found dist: File-RandomGenerator
    prove-author: Found dist: MySQL-ORM
    prove-author: Found dist: MySQL-QueryMulti
    prove-author: Found dist: MySQL-Util
    prove-author: Found dist: MySQL-Util-Lite-ForeignKeyColumn
    prove-author: Found dist: Util-Medley
    prove-author: [DRY] [1/9] Running prove for distribution Backup-Duplicity-YADW (directory /home/u1/repos-other/perl-Backup-Duplicity-YADW) ...
    prove-author: [DRY] [2/9] Running prove for distribution Backup-EZ (directory /tmp/aM6akPpQUe/Backup-EZ-0.43) ...
    prove-author: [DRY] [3/9] Running prove for distribution CLI-Driver (directory /tmp/JkZpohbCMa/CLI-Driver-0.3) ...
    prove-author: [DRY] [4/9] Running prove for distribution File-RandomGenerator (directory /tmp/TU7lm9yjQs/File-RandomGenerator-0.06) ...
    prove-author: [DRY] [5/9] Running prove for distribution MySQL-ORM (directory /tmp/5OstYMM3Ii/MySQL-ORM-0.12) ...
    prove-author: [DRY] [6/9] Running prove for distribution MySQL-QueryMulti (directory /tmp/WKRilHdWOr/MySQL-QueryMulti-0.08) ...
    prove-author: [DRY] [7/9] Running prove for distribution MySQL-Util (directory /tmp/IZS7BH1wtI/MySQL-Util-0.41) ...
    prove-author: [DRY] [8/9] Running prove for distribution MySQL-Util-Lite-ForeignKeyColumn (directory /tmp/Cx9Jy7o3_i/MySQL-Util-0.34) ...
    prove-author: [DRY] [9/9] Running prove for distribution Util-Medley (directory /tmp/_DK2_0kdgC/Util-Medley-0.025) ...

The above example shows that I only have the distribution directories locally on
my `~/repos-other` for one of GRAVATTJ's distributions.

If we reinvoke the above command without the `-n`, *prove-author* will actually
run `prove` on each directory and provide a summary at the end. Example output:

    % prove-author GRAVATTJ
    +-------------------------------------------------+-----------------------------------------------+-----------------------------------+--------+
    | dir                                             | label                                         | reason                            | status |
    +-------------------------------------------------+-----------------------------------------------+-----------------------------------+--------+
    | /home/u1/repos-other/perl-Backup-Duplicity-YADW | distribution Backup-Duplicity-YADW            | Non-zero exit code (255)          | 500    |
    | /tmp/7Jmw0xDarg/Backup-EZ-0.43                  | distribution Backup-EZ                        | Non-zero exit code (25)           | 500    |
    | /tmp/hiiemSXIot/CLI-Driver-0.3                  | distribution CLI-Driver                       | Non-zero exit code (1)            | 500    |
    | /tmp/CsAIDKALXQ/File-RandomGenerator-0.06       | distribution File-RandomGenerator             | Test failed (Failed 1/2 subtests) | 500    |
    | /tmp/DfHp_1ZrZV/MySQL-ORM-0.12                  | distribution MySQL-ORM                        | Non-zero exit code (1)            | 500    |
    | /tmp/XC0t4vZnGo/MySQL-QueryMulti-0.08           | distribution MySQL-QueryMulti                 | Test failed                       | 500    |
    | /tmp/OJ9b7aFljf/MySQL-Util-0.41                 | distribution MySQL-Util                       | Non-zero exit code (1)            | 500    |
    | /tmp/Eb1QtTu2Cu/MySQL-Util-0.34                 | distribution MySQL-Util-Lite-ForeignKeyColumn | Non-zero exit code (1)            | 500    |
    | /tmp/Wui5PMkP98/Util-Medley-0.025               | distribution Util-Medley                      | Test failed (No subtests run)     | 500    |
    +-------------------------------------------------+-----------------------------------------------+-----------------------------------+--------+

The above example shows that all distributions still failed testing (due to lack
of testing requirements). You can scroll up for the detailed `prove` output to
see the details of failure failed, fix things, and re-run.

How distribution directory is searched: see <pm:App::ProveDists> documentation.

When a dependent distribution cannot be found or downloaded/extracted, this
counts as a 412 error (Precondition Failed).

When a distribution's test fails, this counts as a 500 error (Error). Otherwise,
the status is 200 (OK).

*prove-author* will return status 200 (OK) with the status of each dist. It will
exit 0 if all distros are successful, otherwise it will exit 1.

_
    args => {
        %App::ProveDists::args_common,
        author => {
            summary => 'CPAN author IDd prove',
            schema => 'cpan::pause_id*',
            req => 1,
            pos => 0,
        },
    },
    features => {
        dry_run => 1,
    },
};
sub prove_author {
    require App::lcpan::Call;

    my %args = @_;

    my $res = App::lcpan::Call::call_lcpan_script(
        argv => ['author-dists', '-l', $args{author}],
    );

    return [412, "Can't lcpan author-dists: $res->[0] - $res->[1]"]
        unless $res->[0] == 200;

    my @included_recs;
  REC:
    for my $rec (@{ $res->[2] }) {
        log_info "Found dist: %s", $rec->{dist};
        next if grep { $rec->{dist} eq $_->{dist} } @included_recs;
        push @included_recs, {dist=>$rec->{dist}};
    }

    App::ProveDists::prove_dists(
        hash_subset(\%args, \%App::ProveDists::args_common),
        -dry_run => $args{-dry_run},
        _res => [200, "OK", \@included_recs],
    );
}

1;
# ABSTRACT:

=head1 SYNOPSIS

See the included script L<prove-author>.


=head1 SEE ALSO

L<prove>

L<App::lcpan>

L<prove-dirs> from L<App::ProveDirs>

L<prove-dists> from L<App::ProveDists>

L<prove-mods> from L<App::ProveMods>

L<prove-rdeps> from L<App::ProveRdeps>
