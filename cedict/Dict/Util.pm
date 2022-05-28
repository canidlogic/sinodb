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
or more hash references.  Each hash reference is a detected variant
reference.  Depending on the variant format, there are three types of
property sets that might appear.  In the first case, there will be a
property C<han> and a property C<pinyin>.  In the second case, there
will be a property C<han> by itself.  In the third case, there will be
a property C<trad> and a property C<simp>.

The C<han> property is a Han character rendering standing by itself.
The C<trad> and C<simp> properties are Han character renderings given in
a pair to indicate traditional and simpliifed.  The C<pinyin> property
when present is an array reference containing all the detected Pinyin
syllables.

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
      if ($gloss =~ /
                      variant
                      \s+
                      of
                      \s+
                      (\S*[\p{Lo}\x{3000}-\x{303f}\x{25a0}-\x{25ff}]\S*)
                      \s*
                      \[([^\[\]]*)\]
                    /xi) {
        # Get parameters
        my $han    = $1;
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
        
        # Add to results
        push @results, ({
          han    => $han,
          pinyin => \@pnys
        });
      
      } elsif ($gloss =~
                    /
                      variant
                      \s+
                      of
                      \s+
                      (\S*[\p{Lo}\x{3000}-\x{303f}\x{25a0}-\x{25ff}]\S*)
                      \|
                      (\S*[\p{Lo}\x{3000}-\x{303f}\x{25a0}-\x{25ff}]\S*)
                    /xi) {
        # Get parameters
        my $trad = $1;
        my $simp = $2;
        
        # Add to results
        push @results, ({
          trad => $trad,
          simp => $simp
        });
      
      } elsif ($gloss =~
                    /
                      variant
                      \s+
                      of
                      \s+
                      (\S*[\p{Lo}\x{3000}-\x{303f}\x{25a0}-\x{25ff}]\S*)
                    /xi) {
        # Get parameter
        my $han = $1;
        
        # Add to results
        push @results, ({
          han => $han
        });
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
