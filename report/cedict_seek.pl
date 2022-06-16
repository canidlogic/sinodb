#!/usr/bin/env perl
use strict;
use warnings;

# Sino imports
use Sino::Dict;
use SinoConfig;

=head1 NAME

cedict_seek.pl - Seek to and print a parsed record from CC-CEDICT.

=head1 SYNOPSIS

  ./cedict_seek.pl 21873
  ./cedict_seek.pl -12

=head1 DESCRIPTION

This script seeks to the line number given as a parameter and then
prints a parsed representation the CC-CEDICT record at that line.  Use
negative line numbers to select lines in the supplementary definitions
file.

=cut

# ==================
# Program entrypoint
# ==================

# Set output to UTF-8
#
binmode(STDOUT, ':encoding(UTF-8)') or
  die "Failed to set UTF-8 output, stopped";

# Get and check parameter
#
($#ARGV == 0) or die "Wrong number of program arguments, stopped";
my $seek_pos = $ARGV[0];
($seek_pos =~ /\A\-?[0-9]+\z/) or
  die "Can't parse program argument, stopped";
$seek_pos = int($seek_pos);
($seek_pos != 0) or die "Program argument out of range, stopped";

# Load CC-CEDICT data files and rewind
#
my $dict = Sino::Dict->load($config_dictpath, $config_datasets);
$dict->rewind;

# Seek to desired record
#
$dict->seek($seek_pos);

# Read record and make sure line number is correct
#
($dict->advance) or die "Can't find requested record, stopped";
($dict->line_number == $seek_pos) or
  die "Can't find requested record, stopped";

# Print traditional and simplified Han readings
#
printf "%s\n%s\n", $dict->traditional, $dict->simplified;

# Report Pinyin
#
if (defined $dict->pinyin) {
  printf "%s\n", $dict->pinyin;
} else {
  print "< Pinyin can't be normalized >\n";
}

# If proper name, report that
#
if ($dict->is_proper) {
  print "Proper name record\n";
}

# Report any record-level annotations
#
my $rla = $dict->main_annote;

if (scalar(@{$rla->{'measures'}}) > 0) {
  print "\n[Measures]\n";
  for my $measure (@{$rla->{'measures'}}) {
    printf "%s  %s", $measure->[0], $measure->[1];
    if (scalar(@$measure) >= 3) {
      printf "  %s\n", $measure->[2];
    } else {
      print "\n";
    }
  }
}

if (scalar(@{$rla->{'pronun'}}) > 0) {
  print "\n[Alternate pronunciations]\n";
  for my $pronun (@{$rla->{'pronun'}}) {
    printf "%s:", $pronun->[0];
    
    for my $pny (@{$pronun->[1]}) {
      printf "  %s", $pny;
    }
    
    if (length($pronun->[2]) > 0) {
      printf "  %s\n", $pronun->[2];
    } else {
      print "\n";
    }
  }
}

if (scalar(@{$rla->{'xref'}}) > 0) {
  print "\n[Cross-references]\n";
  for my $xref (@{$rla->{'xref'}}) {
    if (length($xref->[0]) > 0) {
      printf "%s ", $xref->[0];
    }
    printf "%s", $xref->[1];
    
    for my $xrr (@{$xref->[2]}) {
      printf " (%s %s", $xrr->[0], $xrr->[1];
      if (scalar(@$xrr) >= 3) {
        printf " %s)", $xrr->[2];
      } else {
        print ")";
      }
    }
    
    if (length($xref->[3]) > 0) {
      printf " %s\n", $xref->[3];
    } else {
      print "\n";
    }
  }
}

# Print each entry
#
for my $entry (@{$dict->entries}) {
  
  # Print header
  printf "\n[Sense %d]\n", $entry->{'sense'};
  
  # Flag indicating whether any annotations were printed
  my $has_annote = 0;
  
  # Report any gloss-level annotations and set annote flag if present
  if (scalar(@{$entry->{'measures'}}) > 0) {
    $has_annote = 1;
    print "-- Measures --\n";
    for my $measure (@{$entry->{'measures'}}) {
      printf "%s  %s", $measure->[0], $measure->[1];
      if (scalar(@$measure) >= 3) {
        printf "  %s\n", $measure->[2];
      } else {
        print "\n";
      }
    }
  }
  
  if (scalar(@{$entry->{'pronun'}}) > 0) {
    $has_annote = 1;
    print "-- Alternate pronunciations --\n";
    for my $pronun (@{$entry->{'pronun'}}) {
      printf "%s:", $pronun->[0];
      
      for my $pny (@{$pronun->[1]}) {
        printf "  %s", $pny;
      }
      
      if (length($pronun->[2]) > 0) {
        printf "  %s\n", $pronun->[2];
      } else {
        print "\n";
      }
    }
  }
  
  if (scalar(@{$entry->{'xref'}}) > 0) {
    $has_annote = 1;
    print "-- Cross-references --\n";
    for my $xref (@{$entry->{'xref'}}) {
      if (length($xref->[0]) > 0) {
        printf "%s ", $xref->[0];
      }
      printf "%s", $xref->[1];
      
      for my $xrr (@{$xref->[2]}) {
        printf " (%s %s", $xrr->[0], $xrr->[1];
        if (scalar(@$xrr) >= 3) {
          printf " %s)", $xrr->[2];
        } else {
          print ")";
        }
      }
      
      if (length($xref->[3]) > 0) {
        printf " %s\n", $xref->[3];
      } else {
        print "\n";
      }
    }
  }

  # Report any citations within this gloss and set annote flag if
  # present
  if (scalar(@{$entry->{'cites'}}) > 0) {
    $has_annote = 1;
    print "-- Citations --\n";
    for my $cite (@{$entry->{'cites'}}) {
      printf "(%d, %d) %s %s",
          $cite->[0], $cite->[1], $cite->[2], $cite->[3];
      
      if (scalar(@$cite) >= 5) {
        printf " %s\n", $cite->[4];
      } else {
        print "\n";
      }
    }
  }

  # If there were any annotations, print ending banner
  if ($has_annote) {
    print "--- (end annotations) ---\n";
  }
  
  # Print the actual gloss text
  printf "%s\n", $entry->{'text'};
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
