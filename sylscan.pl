#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(decode);

# Sino imports
use Sino::DB;
use Sino::Util qw(han_exmap pinyin_count han_count);
use SinoConfig;

=head1 NAME

sylscan.pl - Scan for any word where there is not a clear mapping
between the number of syllables in all Pinyin renderings versus the
number of characters in all Han renderings.

=head1 SYNOPSIS

  ./sylscan.pl

=head1 DESCRIPTION

This script goes through all words in the Sino database, and for each
word examines all of their Han renderings and all of their Pinyin
renderings.

First, the script checks for the special case that a word has exactly
the same number of Han renderings and Pinyin renderings, and that in the
order given, each Han rendering corresponds to a Pinyin rendering with
the same length in characters/syllables.

Second, the script checks for the special case that all Han readings
have exceptional Pinyin mappings, and that the set of exceptional Pinyin
mappings equals the set of Pinyin readings for this word.

If neither of those special cases work, a general matching method is
used, as described below.

For the general method, the script builds up a I<length hash> by
examining all the Han renderings of a word.  The keys of the length hash
are adjusted lengths in Han characters (see the C<han_count> function in
C<Sino::Util>), and the values are zero if there is only a single Han
rendering of this length for the character or one if there are multiple
Han renderings of this length for the character.

Then, for each Pinyin rendering, the script counts the number of
syllables using the C<pinyin_count> function of C<Sino::Util>.  Each
Pinyin rendering of a particular word must have a number of syllables
that is already recorded as a key in the length hash.  If the value in
the hash for this syllable length is zero, then everything is OK since
there is only a single Han rendering of that length, and multiple Pinyin
renderings of that length can be unambiguously associated with that
particular Han rendering.  If the value in the hash for this syllable
length is one, then it is changed to two to "claim" it, so that this
single Pinyin rendering will apply to multiple Han renderings.  The
value in the hash must not already be two, because that would indicate
an ambiguous mapping.

This script will report any cases where there is an ambiguous mapping
between Han renderings and Pinyin renderings within a single word, going
by syllable counts.

=cut

# ==================
# Program entrypoint
# ==================

# Check that no program arguments
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read transaction for everything
#
my $dbh = $dbc->beginWork('r');

# Get a list of all the word IDs
#
my $qr = $dbh->selectall_arrayref(
          'SELECT wordid FROM word ORDER BY wordid ASC');
(ref($qr) eq 'ARRAY') or die "No records to examine, stopped";

my @wordids;
for my $a (@$qr) {
  push @wordids, ($a->[0]);
}

# Check each word
#
for my $wordid (@wordids) {
  
  # Get all Han renderings for this word
  $qr = $dbh->selectall_arrayref(
          'SELECT hantrad FROM han WHERE wordid=?',
          undef,
          $wordid);
  (ref($qr) eq 'ARRAY') or die "Word $wordid missing Han, stopped";
  
  my @hans;
  for my $a (@$qr) {
    my $str = decode('UTF-8', $a->[0],
                      Encode::FB_CROAK | Encode::LEAVE_SRC);
    push @hans, ($str);
  }
  
  # Get all Pinyin renderings for this word
  $qr = $dbh->selectall_arrayref(
          'SELECT pnytext FROM pny WHERE wordid=?',
          undef,
          $wordid);
  (ref($qr) eq 'ARRAY') or die "Word $wordid missing Pinyin, stopped";
  
  my @pnys;
  for my $a (@$qr) {
    my $str = decode('UTF-8', $a->[0],
                      Encode::FB_CROAK | Encode::LEAVE_SRC);
    push @pnys, ($str);
  }
  
  # If there are the exact same number of Han and Pinyin renderings,
  # check for the special case where each element corresponds in length
  my $special_case = 0;
  if ($#hans == $#pnys) {
    $special_case = 1;
    for(my $i = 0; $i <= $#hans; $i++) {
      unless (han_count($hans[$i]) == pinyin_count($pnys[$i])) {
        $special_case = 0;
        last;
      }
    }
  }
  
  # If we got the special case, this record is fine so skip further
  # processing
  if ($special_case) {
    next;
  }
  
  # See if everything has an exceptional mapping
  $special_case = 1;
  for my $h (@hans) {
    unless (defined han_exmap($h)) {
      $special_case = 0;
      last;
    }
  }
  
  # If everything does have an exceptional mapping, check if the
  # exceptional mapping case applies
  if ($special_case) {
    # Get a hash of all Pinyin readings of this word and set each to a
    # value of zero
    my %pyh;
    for my $p (@pnys) {
      $pyh{$p} = 0;
    }
    
    # Check that all exceptional mappings are in the hash and set all of
    # the hash values to one
    for my $h (@hans) {
      if (defined $pyh{han_exmap($h)}) {
        $pyh{han_exmap($h)} = 1;
        
      } else {
        $special_case = 0;
        last;
      }
    }
    
    # If special case flag still on, check finally that all values in
    # the hash have been set to one
    if ($special_case) {
      for my $v (values %pyh) {
        unless ($v) {
          $special_case = 0;
          last;
        }
      }
    }
  }
  
  # If we got the exceptional mapping case, this record is fine so skip
  # further processing
  if ($special_case) {
    next;
  }
  
  # General case -- start a mapping with character/syllable length as
  # the key, and start out by setting the lengths of all Han renderings
  # as keys, with the value of each set to zero if there is a single Han
  # rendering with that length or one if there are multiple Han
  # renderings with that length
  my %lh;
  for my $h (@hans) {
    my $key = han_count($h);
    if (defined $lh{"$key"}) {
      $lh{"$key"} = 1;
    } else {
      $lh{"$key"} = 0;
    }
  }
  
  # Compute the length in syllables of each Pinyin rendering, and for
  # each verify that the length is already in the length mapping and
  # that the mapped value is zero or one, then set the mapped value to
  # two if it is one; report any word IDs where the rules aren't
  # followed
  for my $p (@pnys) {
    # Compute length
    my $syl_count = pinyin_count($p);
    
    # Now begin verification, first checking that there is a Han
    # rendering with the same length
    if (defined $lh{"$syl_count"}) {
      # Second, check cases
      if ($lh{"$syl_count"} == 0) {
        # Only a single Han rendering of this length, so we can have
        # any number of Pinyin for it; do nothing here
        
      } elsif ($lh{"$syl_count"} == 1) {
        # Multiple Han renderings of this length that haven't been
        # claimed yet, so claim them
        $lh{"$syl_count"} = 2;
        
      } else {
        print "$wordid: Pinyin has ambiguous mapping to Han\n";
        last;
      }
      
    } else {
      print "$wordid: Pinyin has no matching Han\n";
      last;
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
