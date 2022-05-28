package Sino::Util;
use parent qw(Exporter);
use strict;

our @EXPORT_OK = qw(
                  han_exmap
                  pinyin_count
                  han_count);

# Core dependencies
use Unicode::Normalize;

=head1 NAME

Sino::Util - Utility functions for Sino.

=head1 SYNOPSIS

  use Sino::Util qw(
        han_exmap
        pinyin_count
        han_count);
  
  # Check whether a Han sequence has an exception Pinyin mapping
  my $pinyin = han_exmap($han);
  if (defined($pinyin)) {
    ...
  }
  
  # Count the number of Pinyin syllables
  my $syl_count = pinyin_count($pny);
  
  # Count the adjusted number of Han syllables
  my $han_count = han_count($han);

=head1 DESCRIPTION

Provides various utility functions.  See the documentation of the
individual functions for further information.

=cut

# =========
# Constants
# =========

# The maximum number of vowel letters in a Pinyin vowel multigraph.
#
my $MAX_VSEQ = 3;

# Hash mapping recognized sequences of vowels to values of one.
#
# No vowel sequence may exceed $MAX_VSEQ in length.
#
# For diacritics, only the acute accent diacritic is shown in this hash.
#
my %PNY_MULTI = (
  'ai' => 1,
  'ao' => 1,
  'ei' => 1,
  'ia' => 1,
  'iao' => 1,
  'ie' => 1,
  'io' => 1,
  'iu' => 1,
  'ou' => 1,
  'ua' => 1,
  'uai' => 1,
  'ue' => 1,
  'ui' => 1,
  'uo' => 1,
  "\x{fc}i" => 1,
  "\x{fc}o" => 1,
  "\x{e1}i" => 1,
  "\x{e1}o" => 1,
  "\x{e9}i" => 1,
  "i\x{e1}" => 1,
  "i\x{e1}o" => 1,
  "i\x{e9}" => 1,
  "i\x{f3}" => 1,
  "i\x{fa}" => 1,
  "\x{f3}u" => 1,
  "u\x{e1}" => 1,
  "u\x{e1}i" => 1,
  "u\x{e9}" => 1,
  "u\x{ed}" => 1,
  "u\x{f3}" => 1,
  "\x{fc}\x{e1}" => 1,
  "\x{fc}\x{e9}" => 1,
  "\x{1d8}" => 1
);

# Exceptional mappings of Han readings to Pinyin readings, for use by
# the han_exmap function.
#
my %HAN_EX = (
  "\x{5B30}\x{5152}" => "y\x{12b}ng\x{e9}r",
  "\x{5973}\x{5152}" => "n\x{1da}\x{e9}r",
  "\x{5B64}\x{5152}" => "g\x{16b}\x{e9}r",
  "\x{9019}\x{88E1}" => "zh\x{e8}l\x{1d0}",
  "\x{9019}\x{88CF}" => "zh\x{e8}l\x{1d0}",
  "\x{9019}\x{5152}" => "zh\x{e8}r",
  "\x{90A3}\x{88E1}" => "n\x{e0}l\x{1d0}",
  "\x{90A3}\x{88CF}" => "n\x{e0}l\x{1d0}",
  "\x{90A3}\x{5152}" => "n\x{e0}r",
  "\x{54EA}\x{88E1}" => "n\x{1ce}l\x{1d0}",
  "\x{54EA}\x{88CF}" => "n\x{1ce}l\x{1d0}",
  "\x{54EA}\x{5152}" => "n\x{1ce}r"
);

=head1 FUNCTIONS

=over 4

=item B<han_exmap(han)>

Given a string containing a Han rendering, return the Pinyin reading of
this Han character if this is an exceptional mapping, or else return
undef if there is no known exception mapping for this Han rendering.

In a couple of cases in the TOCFL data, it is difficult to decide which
Han reading maps to which Pinyin reading using regular rules.  It is
easier in this cases to use a lookup table for exceptions, which this
function provides.

If I<all> the Han readings of a word have exceptional mappings as
returned by this function I<and> all the exceptional Pinyin returned by
this function already exists as Pinyin readings for this word, then use
the mappings returned by this function.  Otherwise, use regular rules
for resolving how Han and Pinyin are mapped in the TOCFL dataset.

=cut

sub han_exmap {
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $h = shift;
  (not ref($h)) or die "Wrong parameter type, stopped";
  
  # Use the lookup table
  my $result = undef;
  if (defined $HAN_EX{$h}) {
    $result = $HAN_EX{$h};
  }
  return $result;
}

=item B<pinyin_count(str)>

Given a string containing TOCFL-formatted Pinyin, return the number of
syllables within the string.

The TOCFL data files contain some inconsistencies in the Pinyin
renderings that this function expects were already cleaned up during by
the C<import_tocfl.pl> script.  No parentheses are allowed in the given
Pinyin, as those should have been expanded into two different
renderings already.  The ZWSP that appears exceptionally in some records
should have already been dropped.  Breve diacritics should have already
been changed into the proper caron diacritics.  The variant lowercase a
codepoint should have already been changed into ASCII lowercase a.
Fatal errors occur if you run this function on Pinyin strings that
haven't been properly cleaned up.

This function should properly handle cases where multiple sequences of
vowels are directly adjacent.  This function will also count a final "r"
at the end of the Pinyin as an additional syllable, since this is
normally written with a separate character.

=cut

sub pinyin_count {
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $p = shift;
  (not ref($p)) or die "Wrong parameter type, stopped";
  
  # Start syllable count at zero
  my $syl_count = 0;
  
  # First of all, decompose to NFD
  $p = NFD($p);
  
  # Second, replace all tonal diacritics with acute accent
  $p =~ s/[\x{300}\x{304}\x{30c}]/\x{301}/g;
  
  # Third, lowercase everything
  $p =~ tr/A-Z/a-z/;
  
  # Fourth, recombine in NFC
  $p = NFC($p);
  
  # Fifth, make sure only lowercase ASCII letters, lowercase u-umlaut,
  # and acute accent vowels (and acute accent u-umlaut) remain
  ($p =~ /\A[a-z\x{fc}\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{1d8}]+\z/) or
    die "Pinyin contains unrecognized characters, stopped";
  
  # Sixth, if the last letter is "r" then drop it and increment syllable
  # count
  if ($p =~ /r\z/) {
    $syl_count++;
    $p = substr $p, 0, -1;
  }
  
  # Seventh, count syllables by processing each sequence of vowels
  for my $vsq ($p =~
              /[aeiou\x{fc}\x{e1}\x{e9}\x{ed}\x{f3}\x{fa}\x{1d8}]+/g) {
    # Get a copy of the vowel sequence
    my $vs = $vsq;
    
    # Keep processing until at most a single vowel remains in the
    # sequence
    until (length($vs) <= 1) {
      # Starting at the longest possible vowel combination that still
      # fits within the string and proceeding backwards to length 2,
      # look for the longest matching vowel multigraph, if there is
      # one
      my $multi_len = 0;
      my $max_multi = $MAX_VSEQ;
      if ($max_multi > length($vs)) {
        $max_multi = length($vs);
      }
      for(my $tl = $max_multi; $tl >= 2; $tl--) {
        # Check if a vowel multigraph of this length exists
        if (defined($PNY_MULTI{substr($vs, 0, $tl)})) {
          # Found a multigraph; set length and stop search
          $multi_len = $tl;
          last;
        }
      }
      
      # If we didn't find a multigraph, set the multigraph length to
      # one so we just process a single vowel
      unless ($multi_len > 0) {
        $multi_len = 1;
      }
      
      # Increase syllable count
      $syl_count++;
      
      # Drop however many vowels we just processed
      $vs = substr($vs, $multi_len);
    }
    
    # We have at most one vowel remaining; if there is a single
    # remaining vowel, increment the syllable count
    if (length($vs) > 0) {
      $syl_count++;
    }
  }
  
  # Return the syllable count
  return $syl_count;
}

=item B<han_count(str)>

Given a string of a Han rendering, return the adjusted count of
characters.  This is not always the same as the length of the string in
codepoints!  The "adjusted" length is designed so that the count
returned by this function can be directly compared to the count returned
by the C<pinyin_count> function.  In order to make this happen, a few
Han characters with rhotic pronunciations that are not erhua must be
counted twice, but only when they are the last character in the
rendering.

=cut

sub han_count {
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $h = shift;
  (not ref($h)) or die "Wrong parameter type, stopped";
  
  # Start with the length in codepoints
  my $result = length($h);
  
  # If the last character is U+4E8C, U+800C, or U+723E, then add an
  # additional increment
  if ($h =~ /[\x{4e8c}\x{800c}\x{723e}]\z/) {
    $result++;
  }
  
  # Return adjusted count
  return $result;
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
