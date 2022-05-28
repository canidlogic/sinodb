#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(encode);

# Sino imports
use Sino::DB;
use Sino::Dict;
use SinoConfig;

=head1 NAME

import_cedict.pl - Import data from CC-CEDICT into the Sino database.

=head1 SYNOPSIS

  ./import_cedict.pl

=head1 DESCRIPTION

This script is used to fill a Sino database with information derived
from the CC-CEDICT data file.  Uses <Sino::DB>, C<Sino::Dict> and
C<SinoConfig>, so you must configure those two correctly before using
this script.  See the documentation in C<Sino::DB> for further
information.

This script should be your third step after using C<createdb.pl> to
create an empty Sino database and C<import_tocfl.pl> to add the TOCFL
data.  This script won't do anything unless the TOCFL data is already
in the database!

This iterates through every record in CC-CEDICT.  For each record, check
whether its traditional character rendering matches something in the
C<han> table.  If it does, then the record's glosses will be imported,
using a major order number unique to this particular record.  The senses
and glosses will be separated into records using the ordering system of
the table; see C<createdb.pl> for further information.

=cut

# ==================
# Program entrypoint
# ==================

# Check that we got no program arguments
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read-write transaction for everything
#
my $dbh = $dbc->beginWork('rw');

# Load the CC-CEDICT dictionary
#
my $dict = Sino::Dict->load($config_dictpath);

# Go through each dictionary record
#
while ($dict->advance) {
  # Get the hanid of the traditional rendering of this dictionary
  # record, or skip this record if there is no hanid
  my $qr = $dbh->selectrow_arrayref(
            'SELECT hanid FROM han WHERE hantrad=?',
            undef,
            encode('UTF-8', $dict->traditional,
                    Encode::FB_CROAK | Encode::LEAVE_SRC));
  (ref($qr) eq 'ARRAY') or next;
  my $hanid = $qr->[0];
  
  # Determine the major order number for this dictionary record as one
  # greater than the previous for this Han character, or 1 if no
  # previous
  my $major_order = 1;
  $qr = $dbh->selectrow_arrayref(
          'SELECT dfnomaj FROM dfn WHERE hanid=? '
          . 'ORDER BY dfnomaj DESC',
          undef,
          $hanid);
  if (ref($qr) eq 'ARRAY') {
    $major_order = $qr->[0] + 1;
  }
  
  # Start the minor order counter at zero so that the first sense will
  # take minor order one
  my $minor_order = 0;
  
  # Go through all the senses
  for my $sense ($dict->senses) {
    
    # Increment the minor order
    $minor_order++;
    
    # Start the gloss order counter at zero so that the first gloss will
    # take gloss order one
    my $gloss_order = 0;
    
    # Go through all the glosses
    for my $gloss (@$sense) {
    
      # Increment the gloss order
      $gloss_order++;
      
      # Get the encoded form of this gloss
      my $gle = encode('UTF-8', $gloss,
                        Encode::FB_CROAK | Encode::LEAVE_SRC);
      
      # Add this gloss to the database
      $dbh->do(
              'INSERT INTO dfn'
              . '(hanid, dfnomaj, dfnomin, dfnogls, dfntext) '
              . 'VALUES (?,?,?,?,?)',
              undef,
                $hanid,
                $major_order,
                $minor_order,
                $gloss_order,
                $gle);
    }
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
