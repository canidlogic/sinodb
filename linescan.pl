#!/usr/bin/env perl
use strict;
use warnings;

=head1 NAME

linescan.pl - Read through all lines from input and report lines
containing specified codepoints.

=head1 SYNOPSIS

  ./linescan.pl 101240-10125f 301-305 2c 2f
  cat file1.txt file2.txt file3.txt | ./linescan.pl 7a 2010-2012

=head1 DESCRIPTION

This script will read standard input line by line.  (To process a
sequence of files, pipe the C<cat> command into this script, as shown in
the synopsis.)

Each program argument specifies either a single codepoint or a range of
codepoints to look for.  All codepoints must be specified in base-16.
For ranges, use a hyphen between low bound and upper bound, with no
whitespace in between.  Any line containing at least one matching
codepoint will be printed to standard output.

Input must be in UTF-8 format.

=cut

# ==================
# Program entrypoint
# ==================

# Switch input to UTF-8, with CR+LF -> LF filtering
#
binmode(STDIN, ":encoding(UTF-8) :crlf") or
  die "Failed to set UTF-8 input, stopped";

# Switch output to UTF-8
#
binmode(STDOUT, ":encoding(UTF-8)") or
  die "Failed to set UTF-8 output, stopped";

# Define the array that will contain integer values for single
# codepoints and subarrays of two for ranges; no sorting is required
#
my @ra;

# Add any given codepoints and ranges to the array
#
for my $pa (@ARGV) {
  # Handle different formats
  if ($pa =~ /\A[0-9a-f]{1,6}\z/i) {
    push @ra, (hex($pa));
    
  } elsif ($pa =~ /\A([0-9a-f]{1,6})\-([0-9a-f]{1,6})\z/i) {
    my $lbound = hex($1);
    my $ubound = hex($2);
    ($lbound <= $ubound) or die "Invalid range '$pa', stopped";
    
    push @ra, ([$lbound, $ubound]);
    
  } else {
    die "Can't parse parameter '$pa', stopped";
  }
}

# Process all input lines
#
while (<STDIN>) {
  # Drop any line break
  chomp;
  
  # Go through each codepoint
  for my $cp (split //) {
    # Get numeric codepoint value
    my $cpv = ord($cp);
    
    # Check whether there is a match
    my $match_found = 0;
    for my $r (@ra) {
      if (ref($r)) {
        # Check whether in range
        if (($cpv >= $r->[0]) and ($cpv <= $r->[1])) {
          $match_found = 1;
          last;
        }
        
      } else {
        # Check whether codepoint match
        if ($cpv == $r) {
          $match_found = 1;
          last;
        }
      }
    }
    
    # If we got a match, print the line and stop iteration through
    # codepoints within line
    if ($match_found) {
      print "$_\n";
      last;
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
