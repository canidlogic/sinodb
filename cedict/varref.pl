#!/usr/bin/env perl
use strict;
use warnings;

# Dict modules
use Dict::Parse;
use Dict::Util;
use DictConfig;

=head1 NAME

varref.pl - Scan the dictionary for variant reference resolutions.

=head1 SYNOPSIS

  ./varref.pl check
  ./verref.pl map

=head1 DESCRIPTION

Makes two or three passes through the dictionary.  On the first pass,
records all detected variant references in two indices, based on the
variant reference format.  However, the second index also stores the
lettercase of the first letter of the Pinyin in the dictionary index, so
that only proper names will be matched to proper names on the second
pass.  Also, and records that have a single gloss
C<Japanese variant of ...> will be excluded and not generate index
entries.

Each index maps a variant reference key to an array reference.  The
array reference stores a subarray reference containing the line numbers
of all records using this variant reference, and then a sequence of one
or more integers, which are the line numbers of records that match the
reference key.

On the second pass, each record is checked whether it satisfies any of
the keys in the two indices.  For any satisfied keys, the line number
of the record is added to the end of the array reference.

If after the second pass there are any entries in the first index that
do not have any resolved references, these entries are moved into a
third index.  But in the process of moving to the third index, the
Pinyin is dropped from all keys, which might result in many-to-one
merging.  A third pass is then made with matching just for this third
index.  This allows a second chance for matching variant links where the
Pinyin given in the link doesn't exactly match the Pinyin in the
destination (happens sometimes with tonal mismatches).

At the end, the script does one of two things, based on whether it was
invoked with C<check> or C<map>.  If invoked with C<check>, this script
prints out all array values in the index where the length is not exactly
two.  These are cases either where there was a variant reference that
doesn't match any other record (in the case of only a single value) or a
variant reference that matches two or more other records.

(Currently, only five missing variant links are found with this script,
and no ambiguous variant links.  The five missing variant links are all
weird cases where it isn't exactly clear what is meant, or involving
obscure cases.)

If the script was invoked with C<map>, then the script will generate a
crossreference map.  Each line is a separate record in the following
format:

  9310: 5 2231 8297

The first integer is a line number in the dictionary file, identifying
a specific record.  Any remaining integers represent the line numbers of
records that are referenced from this record with variant links.  The
remaining integers are sorted in ascending order and never include a
line number equal to the first integer on the line (self references are
filtered out).  The records in the crossreference map are sorted in
ascending order of the first integer.  No records are present for
dictionary entries that do not have any recognized crossreferences that
are not self references.

=cut

# ==================
# Program entrypoint
# ==================

# Get and check argument
#
($#ARGV == 0) or die "Wrong number of program arguments, stopped";
(($ARGV[0] eq 'check') or ($ARGV[0] eq 'map')) or
  die "Invalid invocation mode '$ARGV[0]', stopped";

# Define the index hashes
#
# The h1 hash uses keys that are a traditional Han rendering, a space,
# a simplified Han rendering, a space, and then the Pinyin syllables
# each separated by a single space.
#
# The h2 hash uses keys that are a traditional Han rendering, a space, a
# simplified Han rendering, a space, and either the letter 'U' or 'L'
# indicating whether the Pinyin of the referrer was Uppercase or
# lowercase.
#
my %h1;
my %h2;

# Open the parser
#
my $dict = Dict::Parse->load($config_dictpath);

# First pass -- build the indices, with values being an array storing a
# subarray with the line numbers of where each reference occurred
#
while ($dict->advance) {
  # Get current line number
  my $lnum = $dict->line_number;
  
  # If record has a single sense with a single gloss that is just
  # "Japanese variant of ..." then skip this record
  my @senses = $dict->senses;
  if (scalar(@senses) == 1) {
    if (scalar(@{$senses[0]}) == 1) {
      if ($senses[0]->[0] =~
            /
              \s*
              Japanese
              \s+
              variant
              \s+
              of
              \s+
              \S+
              \s*
            /xi) {
        next;
      }
    }
  }
  
  # Detect variant references for this record
  my @refs = Dict::Util->variants(@senses);
  
  # Record any detected variant references in the indices
  for my $r (@refs) {
    # Handle the different reference formats to get the proper key and
    # a reference to the proper index hash
    my $key;
    my $ir;
    if (scalar(@$r) == 3) {
      # Case (1): traditional simplified pinyin
      $key = $r->[0] . ' ' . $r->[1] . ' ' . $r->[2];
      $ir = \%h1;
      
    } elsif (scalar(@$r) == 2) {
      # Case (2): traditional simplified lettercase
      my $ps = ($dict->pinyin)[0];
      my $cs;
      if ($ps =~ /\A[A-Z]/) {
        $cs = 'U'
      } elsif ($ps =~ /\A[a-z]/) {
        $cs = 'L'
      } else {
        die "Line $lnum: Invalid Pinyin casing, stopped";
      }
      
      $key = $r->[0] . ' ' . $r->[1] . ' ' . $cs;
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
  
  # Determine the casing of the Pinyin string
  my $cs;
  if ($pnystr =~ /\A[A-Z]/) {
    $cs = 'U';
  } elsif ($pnystr =~ /\A[a-z]/) {
    $cs = 'L';
  } else {
    die "Line $lnum: Invalid Pinyin casing, stopped";
  }
  
  # We will build a list of possible keys for this record, along with
  # references to the index they are for
  my @keys;
  
  # First, traditional simplified pinyin for the first index
  push @keys, ([
    $dict->traditional . ' ' . $dict->simplified . ' ' . $pnystr,
    \%h1
  ]);
  
  # Second, traditional simplified lettercase for the second index
  push @keys, ([
    $dict->traditional . ' ' . $dict->simplified . ' ' . $cs,
    \%h2
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

# Figure out all keys in the h1 hash that haven't found any linked entry
# yet
#
my @missing;
for my $key (keys %h1) {
  if (scalar(@{$h1{$key}}) < 2) {
    push @missing, ($key);
  }
}

# For all the missing keys in the h1 hash, move them to the h3 hash,
# except collapse keys by dropping the Pinyin; remove the original keys
# from the h1 hash
#
my %h3;
for my $key (@missing) {
  # Figure out the new key value
  ($key =~ /\A(\S+) (\S+) /) or die "Unexpected";
  my $new_key = "$1 $2";
  
  # If new key not yet defined in the new hash, define it
  unless (defined $h3{$new_key}) {
    $h3{$new_key} = [ [ ] ];
  }
  
  # Copy all line numbers in the original h1 key value into the h3 key
  for my $ln (@{$h1{$key}->[0]}) {
    push @{$h3{$new_key}->[0]}, ( $ln );
  }
  
  # Drop the original key from h1
  delete $h1{$key};
}

# If there was at least one missing key moved to h3, perform third pass
#
if (scalar(@missing) > 0) {
  $dict->rewind;
  while ($dict->advance) {
    # Get current line number
    my $lnum = $dict->line_number;
    
    # Determine key for current record in traditional simplified form
    my $key = $dict->traditional . ' ' . $dict->simplified;
    
    # If key defined in h3, then add this line number
    if (defined $h3{$key}) {
      push @{$h3{$key}}, ( $lnum );
    }
  }
}

# Generate the requested report
#
if ($ARGV[0] eq 'check') { # ===========================================
  # Go through each index and for each report the references that lack
  # any resolution or have multiple resolutions
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

} elsif ($ARGV[0] eq 'map') { # ========================================
  # Define a hash that will map dictionary line numbers to an array ref
  # that holds the line numbers of records referenced from there
  my %rmap;
  
  # Go through the values in each index
  for my $ir (\%h1, \%h2, \%h3) {
    for my $va (values %$ir) {
      # Skip this value if not exactly length two
      (scalar(@$va) == 2) or next;
      
      # Get the target line number
      my $target = $va->[1];
      
      # Add that target to all sources
      for my $src (@{$va->[0]}) {
        # Only add if not a self-reference
        if ($src != $target) {
          # If source already not yet defined in rmap, start an entry
          unless (defined $rmap{"$src"}) {
            $rmap{"$src"} = [];
          }
          
          # Add current target to the source
          push @{$rmap{"$src"}}, ( $target );
        }
      }
    }
  }
  
  # Go through all keys in the generated map in numerical order and
  # print them
  for my $key (sort { int($a) <=> int($b) } keys %rmap) {
    # Get a list of all target references in sorted order
    my @targets = sort { int ($a) <=> int($b) } @{$rmap{$key}};
    
    # Print this map entry
    print "$key:";
    for my $tv (@targets) {
      print " $tv";
    }
    print "\n";
  }
  
} else { # =============================================================
  die "Unexpected";
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
