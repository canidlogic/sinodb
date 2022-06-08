#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(decode);

# Sino imports
use Sino::DB;
use Sino::Util qw(tocfl_pinyin cedict_pinyin);
use SinoConfig;

=head1 NAME

matchpny.pl - Report all word IDs that have any Han rendering where
there is not a common Pinyin between mpy and pny tables.

=head1 SYNOPSIS

  ./matchpny.pl

=head1 DESCRIPTION

This script goes through all Han IDs.  For each, it gets a list of all
TOCFL Pinyin and CC-CEDICT Pinyin.  If there is not at least one common
element between those lists, the word ID of this han ID is added to the
result set.  At the end, a list of word IDs for the result set is
reported.

=cut

# ==================
# Program entrypoint
# ==================

# Set UTF-8 error reporting
#
binmode(STDERR, ':encoding(UTF-8)') or
  die "Failed to set UTF-8 diagnostics, stopped";

# Check that no program arguments
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read transaction for everything
#
my $dbh = $dbc->beginWork('r');

# Get a mapping of all Han IDs to their word IDs
#
my %hanmap;

my $qr = $dbh->selectall_arrayref('SELECT hanid, wordid FROM han');
if (ref($qr) eq 'ARRAY') {
  for my $r (@$qr) {
    $hanmap{"$r->[0]"} = $r->[1];
  }
}
(scalar(%hanmap) > 0) or die "No records to examine, stopped";

# Iterate through all han IDs, building the result set
#
my %results;
for my $key (keys %hanmap) {
  
  # Get Han ID
  my $han_id = int($key);

  # Define match set, where records map to 1 if in mpy table and 2 if
  # in both mpy and pny tables
  my %match_set;

  # Get all mpy pinyin and add to the match set with value set to 1
  $qr = $dbh->selectall_arrayref(
                'SELECT mpypny FROM mpy WHERE hanid=?',
                undef,
                $han_id);
  if (ref($qr) eq 'ARRAY') {
    for my $r (@$qr) {
      my $pny = decode('UTF-8', $r->[0],
                        Encode::FB_CROAK | Encode::LEAVE_SRC);
      my $npny = cedict_pinyin($pny);
      if (defined $npny) {
        $match_set{$npny} = 1;
      } else {
        warn "Invalid CC-CEDICT Pinyin '$pny', continuing";
      }
    }
  }
  
  # If no mpy pinyin, skip this record
  (scalar(%match_set) > 0) or next;
  
  # Get all pny pinyin and for any entries already in match set, set the
  # value to 2
  $qr = $dbh->selectall_arrayref(
                'SELECT pnytext FROM pny WHERE hanid=?',
                undef,
                $han_id);
  my $found_some = 0;
  if (ref($qr) eq 'ARRAY') {
    for my $r (@$qr) {
      $found_some = 1;
      my $pny = decode('UTF-8', $r->[0],
                        Encode::FB_CROAK | Encode::LEAVE_SRC);
      my $npny;
      eval {
        $npny = tocfl_pinyin($pny);
      };
      if ($@) {
        die "Failed with TOCFL Pinyin '$pny', stopped";
      }
      if (defined $match_set{$npny}) {
        $match_set{$npny} = 2;
      }
    }
  }
  
  # Skip this record if no Pinyin in pny table
  ($found_some) or next;
  
  # Check if at least one entry in match set with value 2
  my $found_double = 0;
  for my $val (values %match_set) {
    if ($val == 2) {
      $found_double = 1;
      last;
    }
  }
  
  # If didn't find a common match, add word ID to result set
  unless ($found_double) {
    $results{$hanmap{"$han_id"}} = 1;
  }
}

# If we got here, commit the transaction
#
$dbc->finishWork;

# Print a sorted list of all (unique) word IDs
#
for my $word_id (sort { int($a) <=> int($b) } keys %results) {
  print "$word_id\n";
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
