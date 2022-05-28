#!/usr/bin/env perl
use strict;
use warnings;

=head1 NAME

charscan.pl - Scan all the different characters besides ASCII controls,
whitespace, and ideographs and generate a report.

=head1 SYNOPSIS

  ./charscan.pl file1.txt file2.txt file3.txt ...

=head1 DESCRIPTION

Pass a sequence of zero or more file paths to this script.  Each file
will be scanned separately, but the final results are from across all
the input files.  All codepoints used in the files will be reported,
except for the following:

=over 4

=item *

C<CR> U+000D Carriage Return

=item *

C<LF> U+000A Line Feed

=item *

C<SP> U+0020 Space (regular ASCII)

=item *

Unicode General Category Lo (C<Other_Letter>)

=back

(The C<Lo> class is not reported because it contains a potentially huge
number of ideographs.)

B<Exception:> Characters in Bopomofo blocks I<are> reported.

Each input file must be in UTF-8.  Any leading UTF-8 Byte Order Mark
(BOM) is dropped.

=cut

# ==================
# Program entrypoint
# ==================

# Define the hash that will map decimal character codes to values of 1
#
my %ch;

# Process all given files
#
for(my $i = 0; $i <= $#ARGV; $i++) {
  
  # Check that current file exists
  (-f $ARGV[$i]) or die "Can't find file '$ARGV[$i]', stopped";
  
  # Open file for reading in UTF-8
  open(my $fh, "< :encoding(UTF-8)", $ARGV[$i]) or
    die "Failed to open file '$ARGV[$i]', stopped";
  
  # Read the whole file in
  my $text;
  {
    local $/;
    $text = readline($fh);
    defined($text) or die "Failed to read '$ARGV[$i]', stopped";
  }
  
  # Close the file
  close($fh);
  
  # If the file begins with a decoded Byte Order Mark, drop it
  $text =~ s/\A\x{feff}//;
  
  # Make sure everything in valid Unicode range, and no surrogates
  ($text =~ /\A[\x{0}-\x{d7ff}\x{e000}-\x{10ffff}]*\z/) or
    die "File '$ARGV[$i]' contains invalid codepoints, stopped";
  
  # Go through all sequences of text that don't contain CR, LF, SP, and
  # Lo category characters
  for my $mv ($text =~ /[^\r\n \p{Lo}]+/g) {
    # Go through each individual codepoint in this match
    for my $cp (split //, $mv) {
      # Get the numeric codepoint value
      my $cpv = ord($cp);
    
      # Make sure the codepoint is flagged in the hash
      $ch{"$cpv"} = 1;
    }
  }
  
  # Match any characters in Bopomofo blocks and include them, too
  for my $mv ($text =~ /[\x{3100}-\x{312f}\x{31a0}-\x{31bf}]+/g) {
    # Go through each individual codepoint in this match
    for my $cp (split //, $mv) {
      # Get the numeric codepoint value
      my $cpv = ord($cp);
    
      # Make sure the codepoint is flagged in the hash
      $ch{"$cpv"} = 1;
    }
  }
}

# Get a list of all numeric codepoint values that were found during
# scanning in ascending codepoint order
#
my @cpl = map int, keys %ch;
my @result = sort { $a <=> $b } @cpl;

# Switch output to UTF-8
#
binmode(STDOUT, ":encoding(UTF-8)") or
  die "Failed to set UTF-8 output, stopped";

# Report results
#
for my $rv (@result) {
  # Always begin with the numeric codepoint in base-16, in a fixed field
  # of six
  printf "%6x", $rv;
  
  # Determine the description of the codepoint
  my $desc;
  my $cp = chr($rv);
  
  if ($cp =~ /[\pL\pN\pP\pS]/) {
    # For letters, numbers, punctuation, and symbols, description is
    # just the character itself
    $desc = $cp;
    
  } elsif ($cp =~ /\p{Cc}/) {
    $desc = '<Control>';
    
  } elsif ($cp =~ /\p{Cf}/) {
    $desc = '<Format>';
    
  } elsif ($cp =~ /\p{Cn}/) {
    $desc = '<Unassigned>';
    
  } elsif ($cp =~ /\p{Co}/) {
    $desc = '<Private Use>';
    
  } elsif ($cp =~ /\p{Mc}/) {
    $desc = '<Spacing Mark>';
    
  } elsif ($cp =~ /\p{Me}/) {
    $desc = '<Enclosing Mark>';
    
  } elsif ($cp =~ /\p{Mn}/) {
    $desc = '<Nonspacing Mark>';
    
  } elsif ($cp =~ /\p{Zl}/) {
    $desc = '<Line Separator>';
    
  } elsif ($cp =~ /\p{Zp}/) {
    $desc = '<Paragraph Separator>';
    
  } elsif ($cp =~ /\p{Zs}/) {
    $desc = '<Whitespace>';
    
  } else {
    $desc = '<?>';
  }
  
  # Print description and finish line
  print " $desc\n";
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
