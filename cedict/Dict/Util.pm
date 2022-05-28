package Dict::Util;
use strict;

=head1 NAME

Dict::Util - Utility functions for working with CC-CEDICT.

=head1 SYNOPSIS

  use Dict::Util;
  
  # Detect variant references within word senses
  my @varrefs = Dict::Util->variants(@senses);

=head1 DESCRIPTION

Module providing various utility functions as class methods.

=head1 CLASS METHODS

=over 4

=item B<variants(@senses)>

Detect any variant references within the senses of a word.

This function accepts a sequence of zero or more parameters that must
all be array references containing string glosses to scan.  You can
directly put the return value of the senses method of C<Dict::Parse>
into the parameters of this function to parse all the senses of a word.

The return value from this function is a list in list context of zero
or more array references.  Each array reference is a detected variant
reference.  Either the array includes two elements specifying the
traditional and simplified Han renderings, or it includes three elements
specifying the traditional Han, simplified Han, and the Pinyin (with
exactly one space between syllables and no leading or trailing padding).

See the C<variants.pl> script for further information about recognized
variant reference formats.

=cut

sub variants {
  
  # Drop the class parameter
  shift;
  
  # Start the result array empty
  my @results;
  
  # Scan each parameter
  for my $pv (@_) {
    # Check that parameter is array reference
    (ref($pv) eq 'ARRAY') or die "Invalid parameter type, stopped";
    
    # Scan each gloss in the array
    for my $gloss (@$pv) {
      # Check that gloss is scalar
      (not ref($gloss)) or die "Invalid parameter type, stopped";
    
      # Detect the variant types
      if ($gloss =~
          /
            variant
            \s+
            of
            \s+
            (
              [^\s\|,]*
              [\p{Lo}\x{3000}-\x{303f}\x{25a0}-\x{25ff}]
              [^\s\|,]*
            )
            \|
            (
              [^\s\|,]*
              [\p{Lo}\x{3000}-\x{303f}\x{25a0}-\x{25ff}]
              [^\s\|,]*
            )
            \s*
            \[([^\[\]]*)\]
          /xi) {
        # Get parameters
        my $trad   = $1;
        my $simp   = $2;
        my $pinyin = $3;
        
        # Trim Pinyin of leading and trailing whitespace
        $pinyin =~ s/\A\s+//;
        $pinyin =~ s/\s+\z//;
        
        # Make sure Pinyin after trimming is not empty
        (length($pinyin) > 0) or
          die "Invalid variant reference, stopped";
        
        # Split Pinyin into whitespace-separated tokens
        my @pnys = split ' ', $pinyin;
        ($#pnys >= 0) or die "Unexpected";
        
        # Rejoin Pinyin with exactly one space between
        $pinyin = join ' ', @pnys;
        
        # Add to results
        push @results, ([ $trad, $simp, $pinyin ]);
      
      } elsif ($gloss =~ 
          /
            variant
            \s+
            of
            \s+
            (
              [^\s\|,]*
              [\p{Lo}\x{3000}-\x{303f}\x{25a0}-\x{25ff}]
              [^\s\|,]*
            )
            \s*
            \[([^\[\]]*)\]
          /xi) {
        # Get parameters
        my $trad   = $1;
        my $pinyin = $2;
        
        # Trim Pinyin of leading and trailing whitespace
        $pinyin =~ s/\A\s+//;
        $pinyin =~ s/\s+\z//;
        
        # Make sure Pinyin after trimming is not empty
        (length($pinyin) > 0) or
          die "Invalid variant reference, stopped";
        
        # Split Pinyin into whitespace-separated tokens
        my @pnys = split ' ', $pinyin;
        ($#pnys >= 0) or die "Unexpected";
        
        # Rejoin Pinyin with exactly one space between
        $pinyin = join ' ', @pnys;
        
        # Add to results
        push @results, ([ $trad, $trad, $pinyin ]);
      
      } elsif ($gloss =~
          /
            variant
            \s+
            of
            \s+
            (
              [^\s\|,]*
              [\p{Lo}\x{3000}-\x{303f}\x{25a0}-\x{25ff}]
              [^\s\|,]*
            )
            \|
            (
              [^\s\|,]*
              [\p{Lo}\x{3000}-\x{303f}\x{25a0}-\x{25ff}]
              [^\s\|,]*
            )
          /xi) {
        # Get parameters
        my $trad = $1;
        my $simp = $2;
        
        # Add to results
        push @results, ([ $trad, $simp ]);
      
      } elsif ($gloss =~
          /
            variant
            \s+
            of
            \s+
            (
              [^\s\|,]*
              [\p{Lo}\x{3000}-\x{303f}\x{25a0}-\x{25ff}]
              [^\s\|,]*
            )
          /xi) {
        # Get parameter
        my $trad = $1;
        
        # Add to results
        push @results, ([ $trad, $trad ]);
      }
    }
  }
  
  # Return results array
  return @results;
}

=back

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

# End with something that evaluates to true
#
1;
