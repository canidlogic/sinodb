#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(decode);

# Sino imports
use Sino::DB;
use SinoConfig;

=head1 NAME

wordscan.pl - Report the word IDs of all words that have glosses
matching given keywords.

=head1 SYNOPSIS

  ./wordscan.pl dog

=head1 DESCRIPTION

This script goes through all glosses in the Sino database and records
the word IDs of all words that have any glosses containing all given
keywords.  Keywords are specified as command-line arguments.  If none
are given, a list of all word IDs is returned.  Keyword matching is
case-insensitive, and only ASCII characters may be used in keywords.

Spaces may be included in (quoted) arguments, in which case the space
will be searched for as part of the keyword.

=cut

# ==================
# Program entrypoint
# ==================

# Get all keywords, lowercased
#
my @keywords;
for my $arg (@ARGV) {
  ($arg =~ /\A[\x{20}-\x{7e}]+\z/) or
    die "Keywords must be non-empty and include only ASCII, stopped";
  my $kval = $arg;
  $kval =~ tr/A-Z/a-z/;
  push @keywords, ($kval);
}

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read transaction for everything
#
my $dbh = $dbc->beginWork('r');

# Results hash will map word IDs to 1 for any word IDs that match
#
my %results;

# Prepare a statement for going through all glosses and word IDs
#
my $sth = $dbh->prepare(
  'SELECT han.wordid, dfn.dfntext '
  . 'FROM dfn '
  . 'INNER JOIN mpy ON mpy.mpyid = dfn.mpyid '
  . 'INNER JOIN han ON han.hanid = mpy.hanid'
);

# Run the statement and iterate through all result records
#
$sth->execute;
for(my $rr = $sth->fetchrow_arrayref;
    defined($rr) and ref($rr) eq 'ARRAY';
    $rr = $sth->fetchrow_arrayref) {
  
  # Get the wordid and gloss for this row
  my $wordid = $rr->[0];
  my $gloss  = $rr->[1];
  
  # ASCII lowercase the gloss
  $gloss =~ tr/A-Z/a-z/;
  
  # Start with the accept flag set
  my $accept = 1;
  
  # Go through the keywords, and if any keyword is not found, clear the
  # accept flag
  for my $kw (@keywords) {
    if (index($gloss, $kw) < 0) {
      $accept = 0;
      last;
    }
  }
  
  # If accept flag is still on, add this wordid to the results
  if ($accept) {
    $results{"$wordid"} = 1;
  }
}

# If we got here, commit the transaction
#
$dbc->finishWork;

# Convert the results hash to an array based on the keys, sorted in
# ascending order
#
my @result_arr = map(int, sort { int($a) <=> int($b) } keys %results);

# Print all the results
#
for my $rval (@result_arr) {
  print "$rval\n";
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
