#!/usr/bin/env perl
use strict;
use warnings;

=head1 NAME

countlines.pl - Count how many non-blank lines there are on standard
input.

=head1 SYNOPSIS

  ./countlines.pl < input.txt

=head1 DESCRIPTION

This script will read standard input line by line in binary mode.  The
script will count how many lines have at least one byte in visible,
printing ASCII range [0x21, 0x7E], or in extended range [0x80, 0xFF].

=cut

# ==================
# Program entrypoint
# ==================

# Switch input to raw binary, with CR+LF -> LF filtering
#
binmode(STDIN, ":raw :crlf") or
  die "Failed to set binary input, stopped";

# Check that no arguments
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Process all input lines
#
my $line_count = 0;
while (not eof(STDIN)) {
  # Read next line
  my $ltext;
  (defined($ltext = <STDIN>)) or die "I/O error, stopped";
  
  # Drop any line break
  chomp $ltext;
  
  # Increase count if any visible or extended characters
  if ($ltext =~ /[\x{21}-\x{7e}\x{80}-\x{ff}]/) {
    $line_count++;
  }
}

# Report line count
#
print "Line count: $line_count\n";

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
