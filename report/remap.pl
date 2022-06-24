#!/usr/bin/env perl
use strict;
use warnings;

# Sino imports
use Sino::DB;
use Sino::Op qw(db_to_string string_to_db);
use SinoConfig;

=head1 NAME

remap.pl - Generate a remap list for adding additional remap entries to
the database.

=head1 SYNOPSIS

  ./remap.pl

=head1 DESCRIPTION

This script finds cross-reference annotations belonging to words that do
not have any glosses for any of their meanings, which are below word
level 9, and for which the cross-reference annotation is not already a
Han entry below level 9.

A remap dataset is generated where each line is a record.  Lines begin
with a traditional Han reading from the C<han> table, and then a
sequence of one or more cross-reference traditional Han readings
representing cross-referenced readings found for that entry.  Each
reading is separated by a space.

This script will also verify that none of the cross-referenced readings
are in the generated keyset of remapped traditional Han characters, and
that none of the cross-referenced readings occur more than once.

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
binmode(STDERR, ":encoding(UTF-8)") or
  die "Failed to set UTF-8 diagnostics, stopped";

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read transaction for everything
#
my $dbh = $dbc->beginWork('r');

# Run a SQL query to get a mapping of traditional han readings below
# level 9 to remapped entries, where there might be multiple remapped
# entries per traditional han reading
#
my $sql = q{
  SELECT hantrad, reftrad
  FROM xrm
  INNER JOIN ref ON ref.refid=xrm.refid
  INNER JOIN mpy ON mpy.mpyid=xrm.mpyid
  INNER JOIN han ON han.hanid=mpy.hanid
  INNER JOIN word ON word.wordid=han.wordid
  WHERE
    (wordlevel < 9) AND
    (word.wordid NOT IN
      (SELECT wordid
        FROM dfn
        INNER JOIN mpy ON mpy.mpyid=dfn.mpyid
        INNER JOIN han ON han.hanid=mpy.hanid)) AND
    (reftrad NOT IN
      (SELECT hantrad
        FROM han
        INNER JOIN word ON word.wordid=han.wordid
        WHERE word.wordlevel < 9));
};
my $qr = $dbh->selectall_arrayref($sql);

# Generate a hash from the query results where the keys are traditional
# han readings below level 9 and the values are subarrays storing all
# the remapped entries
#
my %remap;
if (ref($qr) eq 'ARRAY') {
  for my $rec (@$qr) {
    # Get record fields
    my $hantrad = db_to_string($rec->[0]);
    my $xref    = db_to_string($rec->[1]);
    
    # If key not defined yet, define it
    unless (defined $remap{$hantrad}) {
      $remap{$hantrad} = [];
    }
    
    # Add this record
    push @{$remap{$hantrad}}, ($xref);
  }
}

# Go through all the remapped values and make sure that they are not
# present in the keyset, not present among any of the other values, and
# not present as a Han reading in the database below level 9
#
my %valset;
for my $va (values %remap) {
  for my $val (@$va) {
    # Make sure not present in keyset
    (not (defined $remap{$val})) or
      die "$val present in keyset, stopped";
    
    # Make sure not present among other values
    (not (defined $valset{$val})) or
      die "$val duplicated among values, stopped";
    
    # Add to valueset
    $valset{$val} = 1;
    
    # Make sure not in Han table below level 9 (which we should have
    # already filtered out in the original query)
    $qr = $dbh->selectrow_arrayref(
              'SELECT hanid '
              . 'FROM han '
              . 'INNER JOIN word ON word.wordid=han.wordid '
              . 'WHERE (word.wordlevel < 9) AND (han.hantrad = ?)',
              undef,
              string_to_db($val));
    if (ref($qr) eq 'ARRAY') {
      die "Unexpected";
    }
  }
}

# If we got here, commit the transaction
#
$dbc->finishWork;

# Report the hash as the results
#
for my $key (sort keys %remap) {
  print "$key";
  for my $val (@{$remap{$key}}) {
    print " $val";
  }
  print "\n";
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
