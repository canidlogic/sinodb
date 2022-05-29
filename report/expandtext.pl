#!/usr/bin/env perl
use strict;
use warnings;

=head1 NAME

expandtext.pl - Expanded an exported COCT text file into records.

=head1 SYNOPSIS

  ./expandtext.pl < coct.txt > coct.csv

=head1 DESCRIPTION

This script will read UTF-8 text from standard input, line by line.  Any
line that does not have at least 9 ASCII commas on it will be ignored.
Each line with at least 9 ASCII commas will be split up into a sequence
of comma-separated words.  Each of these words will be output on a
single line as two fields separated by a comma, the first field being a
decimal integer identifying the data set and the second field being the
actual word.  The first line with at least 9 ASCII commas is data set 1,
the second line with at least 9 ASCII commas is data set 2, and so
forth.

This script is intended as a conversion aid for the COCT data when you
are using the Word file source.  In this case, convert the Word file to
a UTF-8 plain-text file using LibreOffice Writer or the like.  Then, run
that plain-text file through this script to convert it to CSV.

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

# Check that no program arguments
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Process all input lines
#
my $line_num = 0;
my $dataset_count = 0;
while (not eof(STDIN)) {
  
  # Increase line number
  $line_num++;
  
  # Read the line
  my $ltext;
  (defined($ltext = <STDIN>)) or die "I/O error, stopped";
  
  # If very first line, drop any UTF-8 Byte Order Mark (BOM)
  if ($line_num == 1) {
    $ltext =~ s/\A\x{feff}//;
  }
  
  # Drop any line break
  chomp $ltext;
  
  # Split into words separated by commas
  my @words = split /,/, $ltext;
  
  # Ignore if not at least 10 words
  ($#words >= 9) or next;
  
  # If we got here, increase dataset count
  $dataset_count++;
  
  # Output each non-blank word with whitespace trimming in record format
  for my $w (@words) {
    $w =~ s/\A[ \t]+//;
    $w =~ s/[ \t]+\z//;
    if (length($w) > 0) {
      print "$dataset_count,$w\n";
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
