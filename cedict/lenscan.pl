#!/usr/bin/env perl
use strict;
use warnings;

# Dict modules
use Dict::Parse;
use DictConfig;

=head1 NAME

lenscan.pl - Scan through the CC-CEDICT data file and compile
information about lengths of words containing only common Han
characters and not being proper names.

=head1 SYNOPSIS

  ./lenscan.pl
  ./lenscan.pl -nn 
  ./lenscan.pl -length 5
  ./lenscan.pl -nn -length 7

=head1 DESCRIPTION

Scans through the CC-CEDICT data file.  Only process records where the
traditional rendering contains only codepoints from [U+4E00 U+9FFF],
which are the most common characters.  Compile statistics about how many
records belong to each length class, and also report any exceptional
cases where the number of Pinyin syllables does not match the number of
characters.

If run with the C<-nn> flag, then all proper-name records where the
Pinyin begins with a capital letter will be ignored.

If run with the C<-length> flag, then instead of compiling statistics
and checking for mismatches, this script will report the line numbers of
all records of the given length.

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

# Parse arguments
#
my $no_proper  = 0;
my $len_filter = undef;
for(my $i = 0; $i <= $#ARGV; $i++) {
  if ($ARGV[$i] eq '-nn') {
    $no_proper = 1;
    
  } elsif ($ARGV[$i] eq '-length') {
    ($i < $#ARGV) or die "-length requires parameter, stopped";
    $i++;
    ($ARGV[$i] =~ /\A[1-9][0-9]*\z/) or die "Invalid length, stopped";
    (not defined $len_filter) or
      die "Multiple length filters not allowed, stopped";
    $len_filter = int($ARGV[$i]);
    
  } else {
    die "Unrecognized switch '$ARGV[$i]', stopped";
  }
}

# Open the parser
#
my $dict = Dict::Parse->load($config_dictpath);

# Process records in desired way
#
if (not defined $len_filter) { # =======================================
  # Global length statistics desired
  my %lenstat;
  while ($dict->advance) {
    # Skip this record unless its traditional rendering contains only
    # common CJK ideographs and has at least one characer
    ($dict->traditional =~ /\A[\x{4e00}-\x{9fff}]+\z/) or next;
    
    # Skip this record if it is a proper name and in -nn mode
    if ($no_proper) {
      (not (($dict->pinyin)[0] =~ /\A[A-Z]/)) or next;
    }
    
    # Print line number if syllables mismatches characters
    if (length($dict->traditional) != scalar($dict->pinyin)) {
      printf "Mismatch: %d\n", $dict->line_number;
    }
    
    # Get length in characters
    my $charlen = length($dict->traditional);
    
    # Add to statistics
    if (defined $lenstat{"$charlen"}) {
      $lenstat{"$charlen"} = $lenstat{"$charlen"} + 1;
    } else {
      $lenstat{"$charlen"} = 1;
    }
  }
  
  # Print statistics of length
  for my $k (sort { int($a) <=> int($b) } keys %lenstat) {
    printf "Length %d: %d\n", int($k), $lenstat{$k};
  }
  
} else { # =============================================================
  # Report line numbers of given length
  while ($dict->advance) {
    # Skip this record unless its traditional rendering contains only
    # common CJK ideographs and has at least one characer
    ($dict->traditional =~ /\A[\x{4e00}-\x{9fff}]+\z/) or next;
    
    # Skip this record if it is a proper name and in -nn mode
    if ($no_proper) {
      (not (($dict->pinyin)[0] =~ /\A[A-Z]/)) or next;
    }
    
    # If record has desired number of characters in traditional
    # rendering, print the line number
    if (length($dict->traditional) == $len_filter) {
      printf "%d\n", $dict->line_number;
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
