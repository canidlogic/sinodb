#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(decode);

# Sino imports
use Sino::DB;
use SinoConfig;

=head1 NAME

lenstat.pl - Go through all Han renderings and determine the statistics
for how long in characters they are collectively.

=head1 SYNOPSIS

  ./lenstat.pl

=head1 DESCRIPTION

This script goes through all records in the Han table and records the
length in characters of each entry.  At the end, it prints out the
length statistics across all TOCFL data.

=cut

# ==================
# Program entrypoint
# ==================

# Check that no parameters
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read transaction for everything
#
my $dbh = $dbc->beginWork('r');

# Get all the traditional renderings
#
my $tradr = $dbh->selectall_arrayref('SELECT hantrad FROM han');
(ref($tradr) eq 'ARRAY') or die "No records to examine, stopped";

# Compile length statistics
#
my %lenstat;
for my $trec (@$tradr) {
  my $t = decode('UTF-8', $trec->[0],
                Encode::FB_CROAK | Encode::LEAVE_SRC);
  my $rlen = length($t);
  if (defined $lenstat{"$rlen"}) {
    $lenstat{"$rlen"} = $lenstat{"$rlen"} + 1;
  } else {
    $lenstat{"$rlen"} = 1;
  }
}

# If we got here, commit the transaction
#
$dbc->finishWork;

# Report statistics
#
for my $k (sort { int($a) <=> int($b) } keys %lenstat) {
  printf "Length %d: %d\n", int($k), $lenstat{$k};
}

=head1 AUTHOR

Noah Johnson, C<noah.johnson@loupmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2022 Multimedia Data Technology Inc.

MIT License:

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut
