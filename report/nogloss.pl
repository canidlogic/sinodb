#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(decode);

# Sino imports
use Sino::DB;
use SinoConfig;

=head1 NAME

nogloss.pl - Report the word IDs of all words that don't have any
glosses for any of their Han renderings.

=head1 SYNOPSIS

  ./nogloss.pl
  ./nogloss.pl -min 4
  ./nogloss.pl -max 2
  ./nogloss.pl -multi
  ./nogloss.pl -level 1-6
  ./nogloss.pl -han

=head1 DESCRIPTION

This script goes through all words in the Sino database.  For each word,
it checks whether the word has at least one Han rendering that has an
entry in the C<mpy> major definition table which has at least one gloss
in the C<dfn> table.  The IDs of any words that don't have a single
gloss are reported.

The C<-multi> option, if provided, specifies that only records that have
at least two Han renderings should be checked.

The C<-level> option, if specified, specifies that only records that
have a word level in the given range are considered.

The C<-min> option, if provided, specifies the minimum number of
characters at least one of the Han renderings must have for the record
to be checked.  If not provided, a default of zero is assumed.

The C<-max> option, if provided, specifies the maximum number of
characters I<all> Han renderings must have for the record to be checked.
If not provided, an undefined default is left that indicates there is no
maximum.

The C<-han> option, if provided, prints all the Han traditional
renderings of discovered words instead of their word IDs.

You can mix these options any way you wish.

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
my $min_filter   = undef;
my $max_filter   = undef;
my $level_min    = undef;
my $level_max    = undef;
my $multi_flag   = 0;
my $han_flag     = 0;

for(my $i = 0; $i <= $#ARGV; $i++) {
  if ($ARGV[$i] eq '-min') {
    ($i < $#ARGV) or die "-min requires argument, stopped";
    $i++;
    ($ARGV[$i] =~ /\A[0-9]+\z/) or
      die "Invalid parameter for -min, stopped";
    (not defined $min_filter) or
      die "Can't use -min option multiple times, stopped";
    $min_filter = int($ARGV[$i]);
    
  } elsif ($ARGV[$i] eq '-max') {
    ($i < $#ARGV) or die "-max requires argument, stopped";
    $i++;
    ($ARGV[$i] =~ /\A[0-9]+\z/) or
      die "Invalid parameter for -max, stopped";
    (not defined $max_filter) or
      die "Can't use -max option multiple times, stopped";
    $max_filter = int($ARGV[$i]);
  
  } elsif ($ARGV[$i] eq '-level') {
    ($i < $#ARGV) or die "-level requires argument, stopped";
    $i++;
    (not defined $level_min) or
      die "Can't use -level option multiple times, stopped";
    if ($ARGV[$i] =~ /\A[0-9]+\z/) {
      $level_min = int($ARGV[$i]);
      $level_max = $level_min;
      
    } elsif ($ARGV[$i] =~ /\A([0-9]+)\-([0-9]+)\z/) {
      $level_min = int($1);
      $level_max = int($2);
      
      ($level_min <= $level_max) or die "Invalid level range, stopped";
      
    } else {
      die "Invalid parameter for -level, stopped";
    }
  
  } elsif ($ARGV[$i] eq '-multi') {
    $multi_flag = 1;
    
  } elsif ($ARGV[$i] eq '-han') {
    $han_flag = 1;
    
  } else {
    die "Unrecognized option '$ARGV[$i]', stopped";
  }
}

# Set defaults for undefined options
#
unless (defined $min_filter) {
  $min_filter = 0;
}

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read transaction for everything
#
my $dbh = $dbc->beginWork('r');

# Get all the word IDs in the database, filtering by level here if that
# was specified
#
my @word_list;

my $qr = $dbh->selectall_arrayref(
          'SELECT wordid, wordlevel FROM word ORDER BY wordid ASC');
(ref($qr) eq 'ARRAY') or die "No words in database, stopped";

for my $r (@$qr) {
  my $use_word = 1;
  if (defined $level_min) {
    unless (($r->[1] >= $level_min) and ($r->[1] <= $level_max)) {
      $use_word = 0;
    }
  }
  
  if ($use_word) {
    push @word_list, ( $r->[0] );
  }
}

# Go through all words
#
for my $word_id (@word_list) {
  
  # Set the has_gloss flag to zero initially for this word
  my $has_gloss = 0;
  
  # Get all the hanids and hantrads associated with this word
  my @hans;
  my @hantrads;
  
  $qr = $dbh->selectall_arrayref(
          'SELECT hanid, hantrad FROM han WHERE wordid=?',
          undef,
          $word_id);
  
  if (ref($qr) eq 'ARRAY') {
    for my $r (@$qr) {
      push @hans, ( $r->[0] );
      push @hantrads, ( 
        decode('UTF-8', $r->[1],
                Encode::FB_CROAK | Encode::LEAVE_SRC)
      );
    }
  }
  
  # If multi flag is on, ignore unless at least two Han renderings
  if ($multi_flag) {
    ($#hans >= 1) or next;
  }
  
  # Check that at least one Han rendering has the minimum length
  my $meets_minimum = 0;
  for my $han (@hantrads) {
    if (length($han) >= $min_filter) {
      $meets_minimum = 1;
      last;
    }
  }
  ($meets_minimum) or next;
  
  # If max limit defined, check that all Han renderings meet it
  if (defined $max_filter) {
    my $meets_maximum = 1;
    for my $han (@hantrads) {
      unless (length($han) <= $max_filter) {
        $meets_maximum = 0;
        last;
      }
    }
    ($meets_maximum) or next;
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
  
  # Report word ID or Han readings if no gloss
  unless ($has_gloss) {
    if ($han_flag) {
      for my $reading (@hantrads) {
        print "$reading\n";
      }
    } else {
      print "$word_id\n";
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
