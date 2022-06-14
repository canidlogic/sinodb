#!/usr/bin/env perl
use strict;
use warnings;

# Sino imports
use Sino::COCT;
use Sino::DB;
use Sino::Op qw(
                string_to_db
                wordid_new
                enter_han);
use SinoConfig;

=head1 NAME

import_coct.pl - Import data from COCT into the Sino database.

=head1 SYNOPSIS

  ./import_coct.pl

=head1 DESCRIPTION

This script is used to supplement a Sino database with words from the
COCT vocabulary data file.  This script should be run after using
C<import_tocfl.pl> to import all the TOCFL words.

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

There must be at least one word already defined in the database.  This
script will parse through the COCT vocabulary list.  Only records where
I<all> headwords are not already in the database will be added; if any
of the variant forms are already in the Sino database, the whole COCT
record is skipped.  COCT levels are increased by one before adding into
the database, since COCT levels are one greater than TOCFL levels.

Since C<Sino::COCT> is used as the parser, the blocklist will be
transparently applied.

=cut

# ==================
# Program entrypoint
# ==================

# Check that there are no program arguments
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Open the COCT parser
#
my $cvl = Sino::COCT->load($config_coctpath, $config_datasets);

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read-write transaction for everything
#
my $dbh = $dbc->beginWork('rw');

# Check that at least one word already defined
#
my $ecq = $dbh->selectrow_arrayref('SELECT wordid FROM word');
(ref($ecq) eq 'ARRAY') or
  die "Database doesn't have any words defined yet, stopped";

# Process each COCT record
#
while ($cvl->advance) {
  # Look through all the headwords of this COCT record and determine
  # whether any existing words share any of those headwords
  my $is_shared = 0;
  for my $hwv ($cvl->han_readings) {
    my $qck = $dbh->selectrow_arrayref(
                  'SELECT wordid FROM han WHERE hantrad=?',
                  undef,
                  string_to_db($hwv));
    if (ref($qck) eq 'ARRAY') {
      $is_shared = 1;
      last;
    }
  }
  
  # If any of the headwords are shared, skip this record
  (not $is_shared) or next;
  
  # Insert a brand-new word; determine new word ID as one greater than
  # greatest existing, or 1 if this is the first
  my $wordid = wordid_new($dbc);
  
  # Insert the new word record, with level one greater than COCT level
  my $word_level = $cvl->word_level + 1;
  (($word_level >= 2) and ($word_level <= 8)) or
    die "COCT word level out of range, stopped";
  
  $dbh->do('INSERT INTO word(wordid, wordlevel) VALUES (?,?)',
            undef,
            $wordid, $word_level);
  
  # Add all Han readings
  for my $hwv ($cvl->han_readings) {
    enter_han($dbc, $wordid, $hwv);
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
