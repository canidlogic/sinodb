#!/usr/bin/env perl
use strict;
use warnings;

# Sino imports
use Sino::DB;
use Sino::Op qw(db_to_string);
use SinoConfig;

=head1 NAME

ugloss.pl - Report all glosses that contain non-citation Unicode beyond
ASCII range or square brackets, and the words they belong to.

=head1 SYNOPSIS

  ./ugloss.pl
  ./ugloss.pl -wordid

=head1 DESCRIPTION

This script scans through all glosses in the C<dfn> table.  For each
gloss, all codepoints are examined that are not part of any citation.
If any of these codepoints are outside the range [U+0020, U+007E], or if
any of these codepoints are ASCII square brackets, the gloss is printed
(with citations removed) to output, along with the word ID the gloss
belongs to.

The C<-wordid> causes only a list of word IDs to be reported, rather
than glosses with word IDs.

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

# Parse options
#
my $flag_wordid  = 0;

for(my $i = 0; $i <= $#ARGV; $i++) {
  if ($ARGV[$i] eq '-wordid') {
    $flag_wordid = 1;
    
  } else {
    die "Unrecognized option '$ARGV[$i]', stopped";
  }
}

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read transaction for everything
#
my $dbh = $dbc->beginWork('r');
my $qr;

# Get a list of all the gloss IDs
#
my @gloss_ids;
$qr = $dbh->selectall_arrayref('SELECT dfnid FROM dfn');
if (ref($qr) eq 'ARRAY') {
  for my $rec (@$qr) {
    push @gloss_ids, ($rec->[0]);
  }
}

# Go through all glosses
#
my %id_hash;
for my $gloss_id (@gloss_ids) {
  
  # Get the gloss and word ID
  $qr = $dbh->selectrow_arrayref(
            'SELECT wordid, dfntext '
            . 'FROM dfn '
            . 'INNER JOIN mpy ON mpy.mpyid = dfn.mpyid '
            . 'INNER JOIN han ON han.hanid = mpy.hanid '
            . 'WHERE dfnid=?',
            undef,
            $gloss_id);
  (ref($qr) eq 'ARRAY') or die "Unexpected";
  
  my $word_id = $qr->[0];
  my $gloss   = db_to_string($qr->[1]);
  
  # Get all citation locations within this gloss in reverse order from
  # back of the string to front
  my @cites;
  $qr = $dbh->selectall_arrayref(
            'SELECT citoff, citlen '
            . 'FROM cit WHERE dfnid=? ORDER BY citoff DESC',
            undef,
            $gloss_id);
  if (ref($qr) eq 'ARRAY') {
    for my $crec (@$qr) {
      push @cites, ([$crec->[0], $crec->[1]]);
    }
  }
  
  # With the citations in the order from back of string to front, drop
  # all citations from within the gloss string
  for my $cite (@cites) {
    substr($gloss, $cite->[0], $cite->[1], '');
  }
  
  # Report if gloss contains anything outside of US-ASCII printing range
  # or if it contains square brackets
  unless ($gloss =~ /\A[\x{20}-\x{5a}\x{5c}\x{5e}-\x{7e}]*\z/) {
    if ($flag_wordid) {
      if (not defined $id_hash{"$word_id"}) {
        print "$word_id\n";
        $id_hash{"$word_id"} = 1;
      }
    } else {
      print "$word_id: $gloss\n";
    }
  }
}

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
