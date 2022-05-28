#!/usr/bin/env perl
use strict;
use warnings;

=head1 NAME

dictkey.pl - Generate a keyfile for the CC-CEDICT data file.

=head1 SYNOPSIS

  ./dictkey.pl < cedict.txt > keyfile.txt

=head1 DESCRIPTION

Scans through the CC-CEDICT data file that should be streamed through
standard input.  The following lines are ignored:

  (1) Blank lines
  
  (2) Comment lines beginning with #
  
  (3) Pinyin contains anything other than ASCII alphanumerics/colon/SP
  
  (4) Traditional headword contains Latin letters or digits
  
  (5) Pinyin is "xx" or "xx5"
  
  (6) Pinyin contains a syllablic "m"
  
  (7) Definition starts with /variant

(Case (3) happens when there are proper names with a middle dot or
proverbs with a comma.  Case (4) happens in slang abbreviations.  Case
(5) happens in contracted characters and other situations where there
isn't a straightforward pronunciation.  Case (6) only happens with two
interjections and three dialect variations, none of which are in the
TOCFL dataset.  Case (7) filters out a number of variant cases.)

All other lines that aren't filtered out by the above criteria are
entered into a I<key index>, described below.  The key index is then
printed to output, one line per record, always with traditional
headword, space, Pinyin, space, line number or -1 if ambiguous.

The key index is a key/value map.  The keys consist of the traditional
characters headword, a space, and the Pinyin converted to the same
format as is used in the TOCFL data files, except that an asterisk is
prefixed if the first letter was originally capitalized (and carons are
used on all vowels instead of the breves frequently used in TOCFL data
files).  The values are the line number, where 1 is the first line in
the dictionary file.  There is also the special value -1, which
indicates that more than one dictionary record has the same key, so the
key is ambiguous.

To convert Pinyin the following process is used.  First of all, the
entry is scanned for any alternate Taiwan pronunciations.  To find these
alterante pronunciations scan for the following sequence:

=over 4

=item *
Forward slash character C</>

=item *
Zero or more characters that are not C</>

=item *
C<Taiwan> (case-insensitive)

=item *
One or more spaces or tabs

=item *
C<pr> (case-insensitive)

=item *
Zero or more characters that are not in set C</[]>

=item *
C<[> left-square bracket

=item *
Zero or more spaces or tabs

=item *
ASCII letter

=item *
Zero or more ASCII alphanumerics, colons, spaces, and tabs

=item *
C<]> right-square bracket

=back

Whenever this sequence is found, it adds an alternate Taiwan
pronunciation, consisting of the Pinyin within the square brackets.  The
result should be a list of one or more pronunciations, where the first
pronunciation is the main Pinyin given for the entry, and any additional
pronunications are Taiwan variants discovered within the entry.
(Sometimes the Taiwan variants are only for certain senses of the word.)

Each of the discovered Pinyin sequences is then reformatted using the
same algorithm, described below.

First of all, trim leading and trailing spaces and tabs and then split
into a sequence of tokens separated by whitespace.  Error if there is
not at least one token.

Second, verify that each token ends in a single digit in range [1, 5],
that each token is at least two characters, and that no digits are used
except as the last character.

Third, if the first token begins with an uppercase letter, insert a
special token at the beginning consisting just of the asterisk.

Fourth, convert all tokens to lowercase.

Fifth, replace the sequence C<u:> with a lowercase U-umlaut in all
tokens.

Sixth, make sure each token is either just the asterisk, or a sequence
of ASCII letters and the lowercase U-umlaut followed by a digit [1, 5].

Seventh, for tokens ending in 5, just drop the 5.

Eighth, for remaining tokens that end in a decimal digit, begin by
extracting the decimal digit.  Then, scan for a sequence of one or more
consecutive vowel characters (including the lowercase U-umlaut).  If
there is just a single vowel character, then that is the character that
needs to be modified.  If there are two or three vowel characters, use a
lookup table to figure out which vowel should be modified.  In all other
cases or if no match is found in the lookup table, the conversion
process fails.  Finally, modify the chosen vowel with the selected
diacritic.

Ninth and finally, combine all transformed tokens into a single string
without any separators.

=cut

# =========
# Constants
# =========

# Lookup table mapping sequences of multiple vowels (lowercase) to a
# numeric index indicating which vowel should be modified by tone
# diacritic
#
my %VOWEL_POS = (
  'ai'      => 0,
  'ao'      => 0,
  'ei'      => 0,
  'ia'      => 1,
  'iao'     => 1,
  'ie'      => 1,
  'io'      => 1,
  'iu'      => 1,
  'ou'      => 0,
  'ua'      => 1,
  'uai'     => 1,
  'ue'      => 1,
  'ui'      => 1,
  'uo'      => 1,
  "\x{fc}a" => 1,
  "\x{fc}e" => 1
);

# Lookup mapping each lowercase vowel and lowercase U-umlaut to arrays
# giving the modifications for each of the tone diacritics
#
my %VOWEL_MOD = (
  'a'       => ["\x{101}",  "\x{e1}", "\x{1ce}",  "\x{e0}"],
  'e'       => ["\x{113}",  "\x{e9}", "\x{11b}",  "\x{e8}"],
  'i'       => ["\x{12b}",  "\x{ed}", "\x{1d0}",  "\x{ec}"],
  'o'       => ["\x{14d}",  "\x{f3}", "\x{1d2}",  "\x{f2}"],
  'u'       => ["\x{16b}",  "\x{fa}", "\x{1d4}",  "\x{f9}"],
  "\x{fc}"  => ["\x{1d6}", "\x{1d8}", "\x{1da}", "\x{1dc}"]
);

# ===========
# Module data
# ===========

# The line number in the file we are processing.
#
my $lnum = 0;

# ===============
# Local functions
# ===============

# convert_pinyin(str)
#
# Given a string of Pinyin in CC-CEDICT format, convert it into the
# Unicode format matching that used in the TOCFL data files, with the
# only exception being that Pinyin sequences that originally started
# with a capital letter will have an asterisk prefixed to them (and then
# the rest will be lowercase).  Fatal errors occur on conversion
# problems.
#
sub convert_pinyin {
  # Check and get parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  
  # Save original Pinyin string for error reports
  my $original = $str;
  
  # Trim leading and trailing whitespace
  $str =~ s/\A[ \t]+//;
  $str =~ s/[ \t]+\z//;
  
  # Check that not empty
  (length($str) > 0) or die "Line $lnum: Empty Pinyin, stopped";
  
  # Split into tokens on whitespace
  my @tks = split " ", $str;
  ($#tks >= 0) or die "Unexpected";
  
  # Check that each token is at least two characters, that all
  # characters but the last are ASCII letters or colon, and that the
  # last character is a digit in range [1, 5]
  for my $tk (@tks) {
    ($tk =~ /\A[A-Za-z:]+[1-5]\z/) or
      die "Line $lnum: Invalid Pinyin '$original', stopped";
  }
  
  # If the first token begins with an uppercase letter, insert a special
  # token consisting of just the asterisk at the very beginning
  if ($tks[0] =~ /\A[A-Z]/) {
    unshift @tks, '*';
  }
  
  # Now process tokens individually
  for my $tk (@tks) {
    # Skip the special * token
    if ($tk eq '*') {
      next;
    }
    
    # Begin by converting all ASCII letters to lowercase
    $tk =~ tr/A-Z/a-z/;
    
    # Replace u: with a lowercase U-umlaut
    $tk =~ s/u:/\x{fc}/g;
    
    # Make sure token is now a sequence of one or more ASCII lowercase
    # letters and lowercase U-umlaut, followed by a digit [1-5]; then,
    # split into main token and tone digit
    ($tk =~ /\A([a-z\x{fc}]+)([1-5])\z/) or
      die "Line $lnum: Invalid Pinyin '$original', stopped";
    my $str  = $1;
    my $tone = int($2);
    
    # For every tone except 5, we need to modify the core string
    unless ($tone == 5) {
      # Split into prefix, vowel sequence, and suffix
      ($str =~ /\A([^aeiou\x{fc}]*)([aeiou\x{fc}]+)([^aeiou\x{fc}]*)\z/)
        or die "Line $lnum: Invalid Pinyin '$original', stopped";
      my $prefix = $1;
      my $vowstr = $2;
      my $suffix = $3;
      
      # Split vowels into individual characters
      my @vowels = split //, $vowstr;
      
      # Get the index of the vowel we need to modify
      my $vowel_i = 0;
      if ($#vowels > 0) {
        $vowel_i = $VOWEL_POS{$vowstr}; 
        (defined $vowel_i) or
          die "Line $lnum: Invalid Pinyin '$original', stopped";
      }
      
      # Modify the vowel according to tone
      $vowels[$vowel_i] = $VOWEL_MOD{$vowels[$vowel_i]}->[$tone - 1];
      
      # Rejoin the modified character sequence into the new vowel string
      $vowstr = join '', @vowels;
      
      # Compile the modified token
      $str = $prefix . $vowstr . $suffix;
    }
  
    # Update the token to the possibly modified string
    $tk = $str;
  }
  
  # Rejoin all tokens and that's the result
  return join '', @tks;
}

# ==================
# Program entrypoint
# ==================

# Switch input and output to UTF-8 and CR+LF decoding
#
binmode(STDIN,  ":encoding(UTF-8) :crlf") or
  die "Failed to set UTF-8 input, stopped";
binmode(STDERR, ":encoding(UTF-8) :crlf") or
  die "Failed to set UTF-8 output, stopped";
binmode(STDOUT, ":encoding(UTF-8) :crlf") or
  die "Failed to set UTF-8 output, stopped";

# Check that no program arguments
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Define the hash that will map traditional characters and modified
# Pinyin keys to one-based file line numbers or -1 if ambiguous
#
my %pyh;

# Process the input file line by line
#
$lnum = 0;
for(my $ltext = <STDIN>; defined($ltext); $ltext = <STDIN>) {
  # Increase line number
  $lnum++;
  
  # Drop line break
  chomp $ltext;
  
  # If first line, drop any UTF-8 Byte Order Mark (BOM)
  if ($lnum == 1) {
    $ltext =~ s/\A\x{feff}\z//;
  }
  
  # Skip if blank or starts with #
  if (($ltext =~ /\A[ \t]*\z/) or ($ltext =~ /\A#/)) {
    next;
  }
  
  # Get traditional headword and Pinyin
  ($ltext =~ /\A([^ ]+) [^\[]*\[([^\]]*)\]/) or
    die "Invalid dictionary line '$ltext', stopped";
  my $hword = $1;
  my $pny   = $2;

  # Skip record if Pinyin contains anything other than alphanumeric and
  # colon and space
  ($pny =~ /\A[A-Za-z0-9: ]*\z/) or next;

  # Skip record if traditional headword contains ASCII alphanumerics
  (not ($hword =~ /[A-Za-z0-9]/)) or next;
  
  # Skip record if Pinyin is special xx or xx5 notation
  (not ($pny =~ /\Axx(?:5)?\z/i)) or next;
  
  # Skip record if Pinyin contains lone m syllable
  (not ($pny =~ /\Am[1-5]/i)) or next;
  (not ($pny =~ /[ \t]m[1-5]/i)) or next;
  
  # Skip record if definition starts with /variant
  (not ($ltext =~ /\A[^\/]+\/variant /i)) or next;
 
  # Start Pinyin array with the conversion of the current Pinyin
  my @pa = (convert_pinyin($pny));
  
  # Scan for and add any Taiwan alternate Pinyin
  while ($ltext =~ /
                    \/
                    [^\/]*
                    Taiwan
                    [\x{20}\t]+
                    pr
                    [^\/\[\]]*
                    \[
                    [\x{20}\t]*
                    ([A-Za-z][A-Za-z0-9:\x{20}\t]*)
                    \]
                  /xig) {
    # Convert this Pinyin
    my $pc = convert_pinyin($1);
    
    # Check whether we already have this Pinyin in this record
    my $already = 0;
    for my $p (@pa) {
      if ($p eq $pc) {
        $already = 1;
        last;
      }
    }
    
    # If we don't already have it, add it
    push @pa, ($pc);
  }
  
  # Handle each headword/pinyin combination
  for my $py (@pa) {
    # Assemble the key
    my $kv = "$hword $py";
    
    # Check if key already exists
    if (defined $pyh{$kv}) {
      # Key already defined, so set to ambiguous
      $pyh{$kv} = -1;
      
    } else {
      # Key not defined yet, so define it with the current line number
      $pyh{$kv} = $lnum;
    }
  }
}

# Report the mapping
#
for my $kr (sort keys %pyh) {
  print "$kr $pyh{$kr}\n";
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