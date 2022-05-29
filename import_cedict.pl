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
from the CC-CEDICT data file.  

This script should be your fourth step after using C<createdb.pl> to
create an empty Sino database, C<import_tocfl.pl> to add the TOCFL
data, and C<import_coct.pl> to add the COCT data.  You must have at
least one word defined already in the database or this script will fail.

This iterates through every record in CC-CEDICT.  For each record, check
whether its traditional character rendering matches something in the
C<han> table.  If it does, then the record data will be imported and
linked properly within the Sino database.

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

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

# Check that there is at least one word
#
my $edck = $dbh->selectrow_arrayref('SELECT wordid FROM word');
(ref($edck) eq 'ARRAY') or die "No words defined in database, stopped";

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
  
  # Determine the mpy order number for this dictionary record as one
  # greater than the previous for this Han character, or 1 if no
  # previous
  my $mpy_order = 1;
  $qr = $dbh->selectrow_arrayref(
          'SELECT mpyord FROM mpy WHERE hanid=? '
          . 'ORDER BY mpyord DESC',
          undef,
          $hanid);
  if (ref($qr) eq 'ARRAY') {
    $mpy_order = $qr->[0] + 1;
  }
  
  # Insert the mpy record for this dictionary record, also including the
  # simplified rendering and the CC-CEDICT Pinyin
  $dbh->do(
        'INSERT INTO mpy(hanid, mpyord, mpysimp, mpypny) '
        . 'VALUES (?,?,?,?)',
        undef,
        $hanid, $mpy_order,
        encode('UTF-8', $dict->simplified,
                    Encode::FB_CROAK | Encode::LEAVE_SRC),
        encode('UTF-8', join(' ', $dict->pinyin),
                    Encode::FB_CROAK | Encode::LEAVE_SRC));
  
  # Get the ID of the mpy record we just inserted
  my $mpy_id;
  $qr = $dbh->selectrow_arrayref(
              'SELECT mpyid FROM mpy WHERE hanid=? AND mpyord=?',
              undef,
              $hanid, $mpy_order);
  (ref($qr) eq 'ARRAY') or die "Unexpected";
  $mpy_id = $qr->[0];
  
  # Start the sense order counter at zero so that the first sense will
  # take sense order one
  my $sense_order = 0;
  
  # Go through all the senses
  for my $sense ($dict->senses) {
    
    # Increment the sense order
    $sense_order++;
    
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
              . '(mpyid, dfnosen, dfnogls, dfntext) '
              . 'VALUES (?,?,?,?)',
              undef,
                $mpy_id,
                $sense_order,
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
