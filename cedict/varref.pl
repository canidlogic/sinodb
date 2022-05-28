#!/usr/bin/env perl
use strict;
use warnings;

# Dict modules
use Dict::Parse;
use Dict::Util;
use DictConfig;

=head1 NAME

varref.pl - Scan the dictionary to verify unambiguous variant
references.

=head1 SYNOPSIS

  ./varref.pl

=head1 DESCRIPTION

Makes two passes through the dictionary.  On the first pass, records all
detected variant references in three indices, based on the variant
reference format.  Each index maps a variant reference key to an array
reference.  The array reference stores a subarray reference containing
the line numbers of all records using this variant reference, and then a
sequence of one or more integers, which are the line numbers of records
that match the reference key.

On the second pass, each record is checked whether it satisfies any of
the keys in the three indices.  For any satisfied keys, the line number
of the record is added to the end of the array reference.

At the end, this script prints out all array values in the index where
the length is not exactly two.  These are cases either where there was
a variant reference that doesn't match any other record (in the case of
only a single value) or a variant reference that matches two or more
other records.

=cut

# ==================
# Program entrypoint
# ==================

# Switch output to UTF-8
#
binmode(STDERR, ":encoding(UTF-8)") or
  die "Failed to set UTF-8 output, stopped";
binmode(STDOUT, ":encoding(UTF-8)") or
  die "Failed to set UTF-8 output, stopped";

# Check that no arguments
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Define the index hashes
#
# The h1 hash uses keys that are a Han rendering, a space, and then the
# Pinyin syllables each separated by a single space.
#
# The h2 hash uses keys that are Han rendering by itself.
#
# The h3 hash uses keys that are a traditional Han rendering, a space,
# and a simplified Han rendering
#
my %h1;
my %h2;
my %h3;

# Open the parser
#
my $dict = Dict::Parse->load($config_dictpath);

# First pass -- build the indices, with values being an array storing a
# subarray with the line numbers of where each reference occurred
#
while ($dict->advance) {
  # Get current line number
  my $lnum = $dict->line_number;
  
  # Detect variant references for this record
  my @refs = Dict::Util->variants($dict->senses);
  
  # Record any detected variant references in the indices
  for my $r (@refs) {
    # Handle the different reference formats to get the proper key and
    # a reference to the proper index hash
    my $key;
    my $ir;
    if ((defined $r->{'trad'}) and (defined $r->{'simp'})) {
      # Case (3), both traditional and simplified
      $key = $r->{'trad'} . ' ' . $r->{'simp'};
      $ir = \%h3;
      
    } elsif ((defined $r->{'han'}) and (defined $r->{'pinyin'})) {
      # Case (1), Han and Pinyin
      $key = $r->{'han'};
      for my $py (@{$r->{'pinyin'}}) {
        $key = $key . " $py";
      }
      $ir = \%h1;
      
    } elsif (defined $r->{'han'}) {
      # Case (2), Han by itself
      $key = $r->{'han'};
      $ir = \%h2;
      
    } else {
      die "Unexpected";
    }
    
    # Either add a brand-new key in the index, or add current line
    # number to existing record
    if (defined($ir->{$key})) {
      # Key defined, add this line number
      push @{$ir->{$key}->[0]}, ($lnum);
      
    } else {
      # Key not defined yet, add it
      $ir->{$key} = [ [ $lnum ] ];
    }
  }
}

# Second pass -- record matching line numbers in all indices
#
$dict->rewind;
while ($dict->advance) {
  # Get current line number
  my $lnum = $dict->line_number;
  
  # Build the Pinyin string using spaces between all syllables
  my $pnystr = join ' ', $dict->pinyin;
  
  # We will build a list of possible keys for this record, along with
  # references to the index they are for
  my @keys;
  
  # First, the traditional and pinyin for the first index; if the
  # simplified is different, also add simplified and pinyin for the
  # first index
  push @keys, ([
    $dict->traditional . ' ' . $pnystr,
    \%h1
  ]);
  
  unless ($dict->traditional eq $dict->simplified) {
    push @keys, ([
      $dict->simplified . ' ' . $pnystr,
      \%h1
    ]);
  }
  
  # Second, the traditional by itself for the second index; if
  # simplified is different, also add that for the second index
  push @keys, ([ $dict->traditional, \%h2 ]);
  
  unless ($dict->traditional eq $dict->simplified) {
    push @keys, ([ $dict->simplified, \%h2 ]);
  }
  
  # Third, the traditional and simplified for the third index
  push @keys, ([
    $dict->traditional . ' ' . $dict->simplified,
    \%h3
  ]);
  
  # Now look up all those keys in the proper index and for anything that
  # is found, add a reference to this line number
  for my $kp (@keys) {
    # Get key and index reference
    my $key = $kp->[0];
    my $ir  = $kp->[1];
    
    # Add line number if key is present
    if (defined $ir->{$key}) {
      push @{$ir->{$key}}, ( $lnum );
    }
  }
}

# Go through each index and for each report the references that lack any
# resolution or have multiple resolutions
#
for my $ir (\%h1, \%h2, \%h3) {
  # Go through all values in the index
  for my $va (values %$ir) {
    # Only print it if not exactly length two
    if (scalar(@$va) != 2) {
      # First, print the source records in square brackets
      print '[';
      my $first = 1;
      for my $sr (@{$va->[0]}) {
        if ($first) {
          $first = 0;
        } else {
          print ', ';
        }
        print "$sr";
      }
      print ']:';
      
      # Second, print any of the located records
      for my $tr (@$va) {
        if (not ref($tr)) {
          print " $tr";
        }
      }
      
      # Third, finish the line
      print "\n";
    }
  }
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
