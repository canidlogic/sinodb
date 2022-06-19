#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Unicode::Normalize;

# Sino imports
use Sino::DB;
use Sino::Op qw(
                string_to_db
                db_to_string);
use SinoConfig;

=head1 NAME

tokenize.pl - Build the token tables of the database.

=head1 SYNOPSIS

  ./tokenize.pl

=head1 DESCRIPTION

This script is used to build the token tables within the Sino database.
This should be run after you have imported all the glosses into the
C<dfn> table using C<import_cedict.pl>.  The C<tok> table must be empty
when you start running this script.

Each gloss is analyzed into tokens and the tokens are then recorded in
the token tables within the database.  The token tables allow for
efficient querying of gloss keywords.

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

=cut

# ==================
# Program entrypoint
# ==================

# Check that there are no program arguments
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read-write transaction for everything
#
my $dbh = $dbc->beginWork('rw');
my $qr;

# Make sure there are no tokens yet
#
$qr = $dbh->selectrow_arrayref('SELECT tokid FROM tok');
(not (ref($qr) eq 'ARRAY')) or die "Tokens already present, stopped";

# Get a list of all the gloss IDs
#
my @gloss_ids;
$qr = $dbh->selectall_arrayref('SELECT dfnid FROM dfn');
if (ref($qr) eq 'ARRAY') {
  for my $rec (@$qr) {
    push @gloss_ids, ($rec->[0]);
  }
}

# Process each gloss
#
for my $dfn_id (@gloss_ids) {
  # Get the gloss
  $qr = $dbh->selectrow_arrayref(
            'SELECT dfntext FROM dfn WHERE dfnid=?',
            undef,
            $dfn_id);
  (ref($qr) eq 'ARRAY') or die "Unexpected";
  my $gloss = db_to_string($qr->[0]);
  
  # Get all citation locations within this gloss in reverse order from
  # back of the string to front
  my @cites;
  $qr = $dbh->selectall_arrayref(
            'SELECT citoff, citlen '
            . 'FROM cit WHERE dfnid=? ORDER BY citoff DESC',
            undef,
            $dfn_id);
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
  
  # Remove diacritical combining marks
  $gloss = NFD($gloss);
  $gloss =~ s/[\x{300}-\x{36f}]//g;
  $gloss = NFC($gloss);
  
  # Collapse everything that isn't an ASCII letter or an ASCII
  # apostrophe into spaces
  $gloss =~ s/[^A-Za-z']+/ /g;
  
  # Temporarily change apostrophes that occur between two ASCII letters
  # into ASCII SUB control codes
  $gloss =~ s/([A-Za-z])'([A-Za-z])/$1\x{1a}$2/g;
  
  # Collapse all remaining apostrophes into spaces
  $gloss =~ s/[ ']+/ /g;
  
  # Turn the ASCII SUB control codes back into apostrophes
  $gloss =~ s/\x{1a}/'/g;
  
  # Make everything lowercase
  $gloss =~ tr/A-Z/a-z/;
  
  # Trim leading and trailing whitespace
  $gloss =~ s/\A\s+//;
  $gloss =~ s/\s+\z//;
  
  # Skip this gloss if empty after all these transformations
  (length($gloss) > 0) or next;
  
  # Tokenize with whitespace separators
  my @tokens = split ' ', $gloss;
  
  # Update token tables
  for(my $i = 0; $i <= $#tokens; $i++) {
  
    # Get the token ID, adding a new token if necessary
    my $token_id;
    $qr = $dbh->selectrow_arrayref(
                  'SELECT tokid FROM tok WHERE tokval=?',
                  undef,
                  string_to_db($tokens[$i]));
    if (ref($qr) eq 'ARRAY') {
      # Token already defined, so get the ID
      $token_id = $qr->[0];
      
    } else {
      # Token not defined yet, so determine token ID as one greater than
      # greatest ID, or 1 if this is first token
      $token_id = 1;
      $qr = $dbh->selectrow_arrayref(
                    'SELECT tokid FROM tok ORDER BY tokid DESC');
      if (ref($qr) eq 'ARRAY') {
        $token_id = $qr->[0] + 1;
      }
      
      # Add the new token
      $dbh->do('INSERT INTO tok (tokid, tokval) VALUES (?, ?)',
                undef,
                $token_id, string_to_db($tokens[$i]));
    }
    
    # Add this token record
    $dbh->do('INSERT INTO tkm(tokid, dfnid, tkmpos) VALUES (?, ?, ?)',
              undef,
              $token_id, $dfn_id, $i + 1);
  }
}

# If we got here, commit all our changes as a single transaction
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
