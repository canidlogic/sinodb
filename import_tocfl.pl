#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(encode);

# Sino imports
use Sino::DB;
use Sino::Op qw(
                string_to_db
                wordid_new
                enter_han
                enter_wordclass
                enter_pinyin
              );
use Sino::TOCFL;
use SinoConfig;

=head1 NAME

import_tocfl.pl - Import data from TOCFL into the Sino database.

=head1 SYNOPSIS

  ./import_tocfl.pl

=head1 DESCRIPTION

This script is used to fill a Sino database with information derived
from TOCFL vocabulary data files.  This script should be your second
step after using C<createdb.pl> to create an empty Sino database.

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

Note that the database has the requirement that no two words have the
same Han reading, but there are indeed cases in the TOCFL data where two
different entries have the same Han reading.  When this situation
happens, this script will merge the two entries together into a single
word.  The merger process is explained in further detail in the table
documentation for C<createdb.pl>

This script reads through the TOCFL data with C<Sino::TOCFL>, so it
automatically gets all the correction and normalization features from
that module.

=cut

# ==================
# Program entrypoint
# ==================

# Check that there are no program arguments
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Load the TOCFL parser
#
my $tvl = Sino::TOCFL->load($config_tocfl, $config_datasets);

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read-write transaction for everything
#
my $dbh = $dbc->beginWork('rw');

# Check that nothing in the wclass table or the word table
#
my $ecq = $dbh->selectrow_arrayref('SELECT wclassid FROM wclass');
(not (ref($ecq) eq 'ARRAY')) or
  die "Database already has records, stopped";

$ecq = $dbh->selectrow_arrayref('SELECT wordid FROM word');
(not (ref($ecq) eq 'ARRAY')) or
  die "Database already has records, stopped";

# Add all the word class information to the database; this dataset is
# derived from an auxiliary datasheet that accompanies the TOCFL data
#
for my $wcrec (
    [ 1, 'Adv'    , 'adverb'                              ],
    [ 2, 'Conj'   , 'conjunction'                         ],
    [ 3, 'Det'    , 'determiner'                          ],
    [ 4, 'M'      , 'measure'                             ],
    [ 5, 'N'      , 'noun'                                ],
    [ 6, 'Prep'   , 'preposition'                         ],
    [ 7, 'Ptc'    , 'particle'                            ],
    [ 8, 'V'      , 'verb'                                ],
    [ 9, 'Vi'     , 'intransitive action verb'            ],
    [10, 'V-sep'  , 'intransitive action verb, separable' ],
    [11, 'Vs'     , 'intransitive state verb'             ],
    [12, 'Vst'    , 'transitive state verb'               ],
    [13, 'Vs-attr', 'intransitive state verb, attributive'],
    [14, 'Vs-pred', 'intransitive state verb, predicative'],
    [15, 'Vs-sep' , 'intransitive state verb, separable'  ],
    [16, 'Vaux'   , 'auxiliary verb'                      ],
    [17, 'Vp'     , 'intransitive process verb'           ],
    [18, 'Vpt'    , 'transitive process verb'             ],
    [19, 'Vp-sep' , 'intransitive process verb, separable']
  ) {
  
  $dbh->do(
    'INSERT INTO wclass(wclassid, wclassname, wclassfull) '
    . 'VALUES (?,?,?)',
    undef,
    $wcrec->[0],
    string_to_db($wcrec->[1]),
    string_to_db($wcrec->[2]));
}

# Read through each TOCFL record
#
while ($tvl->advance) {
    
  # Get all the Han readings for this record
  my @hws;
  for my $entry ($tvl->entries) {
    push @hws, ($entry->[0]);
  }
  
  # Look through all the headwords and determine the word IDs of any
  # existing words that share any of those headwords
  my %sharemap;
  for my $hwv (@hws) {
    my $qck = $dbh->selectrow_arrayref(
                  'SELECT wordid FROM han WHERE hantrad=?',
                  undef,
                  string_to_db($hwv));
    if (ref($qck) eq 'ARRAY') {
      $sharemap{"$qck->[0]"} = 1;
    }
  }
  my @sharelist = map(int, keys %sharemap);
  
  # Check that we don't have more than one share
  ($#sharelist < 1) or die "Can't handle multi-mergers, stopped";
  
  # Either add a brand-new word ID or merge this record into an already
  # existing word from the sharelist
  my $wordid;
  if ($#sharelist < 0) {
    # Insert a brand-new word; determine new word ID as one greater than
    # greatest existing, or 1 if this is the first
    $wordid = wordid_new($dbc);
    
    # Insert the new word record
    $dbh->do('INSERT INTO word(wordid, wordlevel) VALUES (?,?)',
              undef,
              $wordid, $tvl->word_level);
  
  } elsif ($#sharelist == 0) {
    # We have an existing word we need to merge this entry into, so get
    # the wordid of this existing word
    $wordid = $sharelist[0];
    
  } else {
    die "Unexpected";
  }
  
  # Add all word classes that aren't already registered for the word
  for my $wcv ($tvl->word_classes) {
    enter_wordclass($dbc, $wordid, $wcv);
  }
  
  # Now add all Han readings and Pinyin readings associated with that
  for my $entry ($tvl->entries) {
    my $han_id = enter_han($dbc, $wordid, $entry->[0]);
    for my $pinyin (@{$entry->[1]}) {
      enter_pinyin($dbc, $han_id, $pinyin);
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
