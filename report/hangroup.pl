#!/usr/bin/env perl
use strict;
use warnings;

# Sino imports
use Sino::DB;
use SinoConfig;

=head1 NAME

hangroup.pl - Generate a listing showing normalized Han groups from the
smp table.

=head1 SYNOPSIS

  ./hangroup.pl

=head1 DESCRIPTION

This script builds lists showing all the Han characters that map to a
normalized Han character.  Han characters that just normalize to
themselves and have no other Han characters in the normal group are not
included.

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

=cut

# ==================
# Program entrypoint
# ==================

# Switch output to UTF-8
#
binmode(STDOUT, ":encoding(UTF-8)") or
  die "Failed to set UTF-8 output, stopped";

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read transaction for everything
#
my $dbh = $dbc->beginWork('r');

# Go through all the smp records in order first of increasing normalized
# codepoint and second of increasing source codepoint
#
my $sth = $dbh->prepare(
                  'SELECT smpsrc, smpnorm '
                  . 'FROM smp '
                  . 'ORDER BY smpnorm ASC, smpsrc ASC');
$sth->execute;

my $current_norm = undef;

for(my $rec = $sth->fetchrow_arrayref;
    defined $rec;
    $rec = $sth->fetchrow_arrayref) {
  
  # Get current record fields
  my $src  = $rec->[0];
  my $norm = $rec->[1];
  
  # If current normalized codepoint is undefined or not equal to
  # record's normalized codepoint, we need to start a new record row
  if (not defined $current_norm) {
    printf "%s:", chr($norm);
    $current_norm = $norm;
    
  } elsif ($current_norm != $norm) {
    printf "\n%s:", chr($norm);
    $current_norm = $norm;
  }
  
  # Print this record, but only if codepoint not equal to normalized
  # codepoint
  unless ($src == $norm) {
    printf " %s", chr($src);
  }
}

# Print final line break
#
print "\n";

# If we got here, commit the transaction
#
$dbc->finishWork;

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
