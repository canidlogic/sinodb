#!/usr/bin/env perl
use strict;
use warnings;

# Sino imports
use Sino::DB;
use SinoConfig;

=head1 NAME

nogloss.pl - Report the word IDs of all words that don't have any
glosses for any of their Han renderings.

=head1 SYNOPSIS

  ./nogloss.pl

=head1 DESCRIPTION

This script goes through all words in the Sino database.  For each word,
it checks whether the word has at least one Han rendering that has an
entry in the C<mpy> major definition table which has at least one gloss
in the C<dfn> table.  The IDs of any words that don't have a single
gloss are reported.

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

=cut

# ==================
# Program entrypoint
# ==================

# Make sure no program arguments
#
($#ARGV < 0) or die "No expecting program arguments, stopped";

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read transaction for everything
#
my $dbh = $dbc->beginWork('r');

# Get all the word IDs in the database
#
my @word_list;

my $qr = $dbh->selectall_arrayref(
          'SELECT wordid FROM word ORDER BY wordid ASC');
(ref($qr) eq 'ARRAY') or die "No words in database, stopped";

for my $r (@$qr) {
  push @word_list, ( $r->[0] );
}

# Go through all words
#
for my $word_id (@word_list) {
  
  # Set the has_gloss flag to zero initially for this word
  my $has_gloss = 0;
  
  # Get all the hanids associated with this word
  my @hans;
  
  $qr = $dbh->selectall_arrayref(
          'SELECT hanid FROM han WHERE wordid=?',
          undef,
          $word_id);
  
  if (ref($qr) eq 'ARRAY') {
    for my $r (@$qr) {
      push @hans, ( $r->[0] );
    }
  }
  
  # Go through all the hanids
  for my $han_id (@hans) {
  
    # Get all the mpyids associated with this Han rendering
    my @mopys;
    
    $qr = $dbh->selectall_arrayref(
            'SELECT mpyid FROM mpy WHERE hanid=?',
            undef,
            $han_id);
    if (ref($qr) eq 'ARRAY') {
      for my $r (@$qr) {
        push @mopys, ( $r->[0] );
      }
    }
    
    # Look for if there is at least one mpyid that has at least one
    # gloss
    for my $mpy_id (@mopys) {
      
      # Check whether there is a gloss
      $qr = $dbh->selectrow_arrayref(
              'SELECT dfnid FROM dfn WHERE mpyid=?',
              undef,
              $mpy_id);
      
      # If at least one gloss, set has_gloss and leave loop
      if (ref($qr) eq 'ARRAY') {
        $has_gloss = 1;
        last;
      }
    }
    
    # If we found a gloss, we can stop going through hanids
    if ($has_gloss) {
      last;
    }
  }
  
  # Report word ID if no gloss
  unless ($has_gloss) {
    print "$word_id\n";
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
