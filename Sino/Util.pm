package Sino::Util;
use parent qw(Exporter);
use strict;

# We will use UTF-8 in string literals and some regular expressions.
#
# The extended character set in this source file is limited to diacritic
# characters used in standard Pinyin.
#
use utf8;

our @EXPORT_OK = qw(
                  parse_blocklist
                  han_exmap
                  pinyin_count
                  han_count
                  parse_measures
                  extract_pronunciation
                  extract_xref
                  tocfl_pinyin);

# Core dependencies
use Unicode::Normalize;

=head1 NAME

Sino::Util - Utility functions for Sino.

=head1 SYNOPSIS

  use Sino::Util qw(
        parse_blocklist
        han_exmap
        pinyin_count
        han_count
        parse_measures
        extract_pronunciation
        extract_xref
        tocfl_pinyin);
  
  # Get the blocklist with each traditional character in a hash
  use SinoConfig;
  my $blocks = parse_blocklist($config_datasets);
  if (defined $blocks->{$han}) {
    # $han is in the blocklist
    ...
  }
  
  # Check whether a Han sequence has an exception Pinyin mapping
  my $pinyin = han_exmap($han);
  if (defined($pinyin)) {
    ...
  }
  
  # Count the number of Pinyin syllables
  my $syl_count = pinyin_count($pny);
  
  # Count the adjusted number of Han syllables
  my $han_count = han_count($han);
  
  # Parse a gloss containing classifier/measure words
  my $measures = parse_measures($gloss);
  if (defined $measures) {
    for my $measure (@$measures) {
      ...
    }
  }
  
  # Parse a gloss containing a pronunciation annotation
  my $result = extract_pronunication($gloss);
  if (defined($result)) {
    my $altered_gloss = $result->[0];
    my $context       = $result->[1];
    my $pinyin_array  = $result->[2];
    my $condition     = $result->[3];
    if (length($altered_gloss) > 0) {
      # Pronunciation is annotation on this specific altered gloss
      ...
    } else {
      # Pronunciation is annotation on major entry
      ...
    }
  }
  
  # Parse a gloss containing a cross-reference annotation
  my $result = extract_xref($gloss);
  if (defined($result)) {
    my $altered_gloss = $result->[0];
    my $descriptor    = $result->[1];
    my $xref_type     = $result->[2];
    my $xref_array    = $result->[3];
    my $xref_suffix   = $result->[4];
    if (length($altered_gloss) > 0) {
      # Cross-reference is for this gloss specifically
      ...
    } else {
      # Cross-reference applies to major entry
      ...
    }
    for my $xref (@$xref_array) {
      my $han_trad = $xref->[0];
      my $han_simp = $xref->[1];
      my $pinyin;
      if (scalar(@$xref) >= 3) {
        $pinyin = $xref->[2];
      }
    }
  }
  
  # Convert TOCFL-style Pinyin to standard Pinyin
  my $standard_pinyin = tocfl_pinyin($tocfl_pinyin);

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

# Hash representing a set of recognized Pinyin sequences of vowels.
#
# No vowel sequence may exceed $MAX_VSEQ in length.  This does hash does
# not store single vowels, only multi-vowel sequences.
#
# For diacritics, only the acute accent diacritic is shown in this hash.
#
my %PNY_MULTI = (
  'ai'  => 1,
  'ao'  => 1,
  'ei'  => 1,
  'ia'  => 1,
  'iao' => 1,
  'ie'  => 1,
  'io'  => 1,
  'iu'  => 1,
  'ou'  => 1,
  'ua'  => 1,
  'üa'  => 1,
  'uai' => 1,
  'ue'  => 1,
  'üe'  => 1,
  'ui'  => 1,
  'uo'  => 1,
  'ái'  => 1,
  'áo'  => 1,
  'éi'  => 1,
  'iá'  => 1,
  'iáo' => 1,
  'ié'  => 1,
  'ió'  => 1,
  'iú'  => 1,
  'óu'  => 1,
  'uá'  => 1,
  'üá'  => 1,
  'uái' => 1,
  'ué'  => 1,
  'üé'  => 1,
  'uí'  => 1,
  'uó'  => 1
);

# Hash that maps erroneous TOCFL Pinyin to corrected versions.
#
# This handles a few typos where the tonal diacritic was placed on the
# wrong vowel.
#
# To query this hash, you must have already "cleaned up" the TOCFL
# Pinyin by converting any uppercase initial letter to lowercase,
# dropping ZWSPs, normalizing variant lowercase a to ASCII a, and
# changing breve diacritics to caron diacritics.
#
my %PNY_TYPO = (
  'piàolìang'  => 'piàoliàng',
  'bǐfāngshūo' => 'bǐfāngshuō',
  'shoúxī'     => 'shóuxī'
);

# Hash representing a set of exceptional TOCFL Pinyin, for use by the
# tocfl_pinyin function.
#
# The Pinyin in this hash are all cases where ng between vowels should
# be converted to G (final ng) instead of Ng (n-g).
#
# To query this hash, you must have already "cleaned up" the TOCFL
# Pinyin by converting any uppercase initial letter to lowercase,
# dropping ZWSPs, normalizing variant lowercase a to ASCII a, changing
# breve diacritics to caron diacritics, and correcting typos.
#
my %NG_EXCEPTION = (
  'píngān'          => 1,
  'zhàngài'         => 1,
  'zǒngéryánzhī'    => 1,
  'dǎngàn'          => 1,
  'fāngàn'          => 1,
  'jìngài'          => 1,
  'xiāngqīnxiāngài' => 1,
  'yīngér'          => 1,
  'chǒngài'         => 1,
  'cóngér'          => 1,
  'dìngé'           => 1,
  'fángài'          => 1,
  'gōngān'          => 1,
  'míngé'           => 1,
  'téngài'          => 1,
  'zǒngé'           => 1
);

# Hash representing a set of exceptional TOCFL Pinyin, for use by the
# tocfl_pinyin function.
#
# The Pinyin in this hash are all cases where n between vowels should be
# converted to N (final n) instead of n (initial n).
#
# To query this hash, you must have already "cleaned up" the TOCFL
# Pinyin by converting any uppercase initial letter to lowercase,
# dropping ZWSPs, normalizing variant lowercase a to ASCII a, changing
# breve diacritics to caron diacritics, and correcting typos.
#
my %N_EXCEPTION = (
  'fǎnér'      => 1,
  'liànài'     => 1,
  'gǎnēn'      => 1,
  'jīné'       => 1,
  'qīnài'      => 1,
  'ránér'      => 1,
  'yībānéryán' => 1,
  'yīnér'      => 1,
  'ànàn'       => 1,
  'bànàn'      => 1,
  'biǎné'      => 1,
  'ēnài'       => 1,
  'jìnér'      => 1,
  'rénài'      => 1,
  'shēnào'     => 1,
  'xīnài'      => 1
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

=item B<parse_blocklist($config_datasets)>

Given the path to the datasets directory defined by the configuration
file in configuration variable C<config_datasets>, read the full
blocklist file and return a hash reference where the keys are the
headwords in the blocklist and the values are all one.

=cut

sub parse_blocklist {
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $datasets_folder = shift;
  (not ref($datasets_folder)) or die "Wrong parameter type, stopped";
  
  # Get the path to the full blocklist
  my $blocklist_path = $datasets_folder . "blocklist.txt";
  
  # Make sure blocklist file exists
  (-f $blocklist_path) or
    die "Can't find blocklist '$blocklist_path', stopped";
  
  # Open blocklist for reading in UTF-8 and CR+LF translation mode
  open(my $fh, "< :encoding(UTF-8) :crlf", $blocklist_path) or
    die "Can't open blocklist file '$blocklist_path', stopped";
  
  # Read all records into a hash
  my %blocklist;
  my $lnum = 0;
  while (not eof($fh)) {
    
    # Increment line number
    $lnum++;
    
    # Read a line
    my $ltext = readline($fh);
    (defined $ltext) or die "I/O error, stopped";
    
    # Drop line breaks
    chomp $ltext;
    
    # If this is first line, drop any UTF-8 BOM
    if ($lnum == 1) {
      $ltext =~ s/\A\x{feff}//;
    }
    
    # Ignore blank lines
    (not ($ltext =~ /\A\s*\z/)) or next;
    
    # Drop leading and trailing whitespace
    $ltext =~ s/\A\s+//;
    $ltext =~ s/\s+\z//;
    
    # Make sure we just have a sequence of one or more Letter_other
    # category codepoints remaining
    ($ltext =~ /\A[\p{Lo}]+\z/) or
      die "Blocklist line $lnum: Invalid record, stopped";
    
    # Add to blocklist
    $blocklist{$ltext} = 1;
  }
  
  # Close blocklist file
  close($fh);
  
  # Return reference to blocklist
  return \%blocklist;
}

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

=item B<parse_measures(str)>

Given a string containing a gloss, parse it as a special gloss
containing measure/classifier words, if possible.

The given string must be a Unicode string.  Do not pass a binary string
that is encoded in UTF-8.

If the given string is recognized as a gloss containing measure words
and nothing else, then this function will return an array reference to a
non-empty array.  Each array element will be a reference to a subarray.
Each subarray has three elements:  the traditional Han rendering of the
measure word, the simplified Han rendering of the measure word, and the
Pinyin syllables (in CC-CEDICT format, with no surrounding square
brackets).  If traditional and simplified Han renderings are the same,
the same string is duplicated across both.  It is possible for words to
have multiple measure words in one of these glosses, in which case the
returned array will have more than one element.

The Pinyin will be normalized with a single space between syllables, no
leading or trailing whitespace, and at least one syllable.  Also, all
syllables will be verified to be a sequence of one or more lowercase
ASCII letters and colons followed by a single decimal digit in range
1-5.  No further checking is performed beyond that.  If the Pinyin
doesn't normalize correctly (for example, there is an uppercase letter),
then this function will return C<undef> indicating the gloss is not a
valid measures gloss.

If the given string is not recognized as a gloss containing measure
words, then C<undef> is returned.

=cut

sub parse_measures {
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  
  # Start with an undefined result
  my $result = undef;
  
  # Only proceed if we get a basic match on the format
  if ($str =~
        /\A
          \s*
          CL\s*:
          \s*
          (
            [\x{4e00}-\x{9fff}]+
            (?:\|[\x{4e00}-\x{9fff}]+)?
            \s*
            \[
            [^\[\],]+
            \]
            (?:
              \s*
              ,
              \s*
              [\x{4e00}-\x{9fff}]+
              (?:\|[\x{4e00}-\x{9fff}]+)?
              \s*
              \[
              [^\[\],]+
              \]
            )*
          )
          \s*
        \z/xi) {

    # Get the raw classifier string
    my $class_raw = $1;
    
    # Split into separate classifier entries separated by commas
    my @classes = split /,/, $class_raw;
    ($#classes >= 0) or die "Unexpected";
    
    # Create a results array and fill it with each of the parsed
    # classifiers
    my @results;
    my $parse_ok = 1;
    for my $class_raw (@classes) {
      # Parse this class
      ($class_raw =~
                    /
                      \s*
                      (
                        [\x{4e00}-\x{9fff}]+
                        (?:\|[\x{4e00}-\x{9fff}]+)?
                      )
                      \s*
                      \[
                        ([^\[\],]+)
                      \]
                      \s*
                    /x) or die "Unexpected";
      my $han_raw = $1;
      my $pny_raw = $2;
      
      # Get traditional and simplified Han readings
      my $han_trad;
      my $han_simp;
      if ($han_raw =~ /\|/) {
        my @ha = split /\|/, $han_raw;
        ($#ha == 1) or die "Unexpected";
        $han_trad = $ha[0];
        $han_simp = $ha[1];
        
      } else {
        $han_trad = $han_raw;
        $han_simp = $han_raw;
      }
      
      # Trim leading and trailing whitespace from Pinyin, and parsing
      # fails if result is empty
      $pny_raw =~ s/\A\s+//;
      $pny_raw =~ s/\s+\z//;
      unless (length($pny_raw) > 0) {
        $parse_ok = 0;
        last;
      }
      
      # Split Pinyin into syllables separated by whitespace
      my @syls = split ' ', $pny_raw;
      ($#syls >= 0) or die "Unexpected";
      
      # Verify that each Pinyin syllable is a sequence of one or more
      # lowercase ASCII letters and colons, followed by a decimal digit
      # in range 1-5, else parsing fails
      for my $syl (@syls) {
        unless ($syl =~ /\A[a-z][a-z:]*[1-5]\z/) {
          $parse_ok = 0;
          last;
        }
      }
      ($parse_ok) or last;
      
      # Get finished pinyin by rejoining syllables with a single space
      # between
      my $pinyin = join ' ', @syls;
      
      # Add to results
      push @results, ([$han_trad, $han_simp, $pinyin]);
    }

    # If parsing was OK, set the return result as a reference to the
    # results array
    if ($parse_ok) {
      $result = \@results;
    }
  }

  # Return result
  return $result;
}

=item B<extract_pronunciation(str)>

Given a string containing a gloss, attempt to extract an alternate
pronunciation annotation.

The given string must be a Unicode string.  Do not pass a binary string
that is encoded in UTF-8.

If the given string has a recognized alternate pronunciation annotation
within it, then the return value is an array reference with four
elements.

The first element is the gloss with the alternate pronunciation
annotation removed.  This may be an empty string if the alternate
pronunciation annotation was the only thing in the gloss.  If this
element is an empty string, then the alternate pronunciation applies to
the whole mpy entry.  If this element is not empty, then the alternate
pronunciation applies just to this particular gloss.

The second element is the context in which this alternate pronunciation
is used.  The most generic value for this element is C<also> which means
an alternate pronunciation.  It can also be something specific like
C<Beijing> C<Taiwan> C<colloquially> C<old> C<commonly> and so forth.
The context is never empty.

The third element is an array reference to a subarray storing the Pinyin
strings for the alternate pronunciation.  Each string has normalized
Pinyin such that there is exactly one space between syllables, no
leading or trailing whitespace, and at least one syllable.  Pinyin
syllables must be a lowercase or uppercase ASCII letter, followed by
zero or more lowercase ASCII letters or colons, followed by a decimal
digit in range 1-5.  There will be at least one Pinyin string in the
array.

The fourth and final element is a string specifying a condition for when
the alternate pronunciation is used.  It may be empty if there is no
special condition.  Otherwise, it is a description of the condition when
to use this pronunciation, written in plain English.

If no pronunciation annotation could be found in the given entry, then
this function returns C<undef>.

=cut

sub extract_pronunciation {
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  
  # Start with an undefined result
  my $result = undef;
  
  # If we have a gloss starting with "(coll.) also pr." then replace
  # this with "colloquial pr."
  $str =~ s/\A\s*\(coll\.\)\s*also\s+pr\./colloquial pr\./i;
  
  # Rewrite exceptional phrase "Taiwan pr. for this sense is [...]" as
  # "Taiwan pr. [...] for this sense"
  $str =~ s/
            Taiwan
            \s+
            pr\.
            \s+
            for
            \s+
            this
            \s+
            sense
            \s+
            is
            \s*\[([^\[\]]*)\]
        /Taiwan\x{20}pr\.\x{20}\[$1\]\x{20}for\x{20}this\x{20}sense/xig;
  
  # Define variables that will hold parsing results
  my $parse_ok = 0;
  my $context;
  my $pinyin_keys;
  my $condition;
  my $altered;
  
  # Check if we can parse this into a parenthetical:  a prefix (which
  # might be empty), a pronunciation gloss in parentheses, and a suffix
  # (which might be empty), or as a pronunciation gloss taking a full
  # entry, optionally with parentheses
  if ($str =~
        /\A
          \s*
          (?:\(\s*)?
          (also|Beijing|Taiwan|colloquial|old|commonly)
          \s+
          pr\.
          \s*
          (
            \[
            [^\[\]]*
            \]
            (?:
              \s*
              or
              \s*
              \[
              [^\[\]]*
              \]
            )?
          )
          (
            \s*
            (?:
              (?:
                (?:for|when|etc|in|before)
                (?:\s+[^\(\)]*)?
              )
            )?
          )
          (?:\s*\))?
          \s*
        \z/xi) {
    # Pronuncation gloss by itself; get components
    $context     = $1;
    $pinyin_keys = $2;
    $condition   = $3;
    
    # Altered gloss is empty in this case
    $altered = '';
    
    # Set parse_ok flag
    $parse_ok = 1;
    
  } elsif ($str =~
        /\A
          (.*)
          \(
          \s*
          (also|Beijing|Taiwan|colloquial|old|commonly)
          \s+
          pr\.
          \s*
          (
            \[
            [^\[\]]*
            \]
            (?:
              \s*
              or
              \s*
              \[
              [^\[\]]*
              \]
            )?
          )
          (
            \s*
            (?:
              (?:
                (?:for|when|etc|in|before)
                \s+
                [^\(\)]+
              )
            )?
          )
          \s*
          \)
          (.*)
        \z/xi) {
    # Pronunciation gloss not the only thing; get components
    my $prefix      = $1;
       $context     = $2;
       $pinyin_keys = $3;
       $condition   = $4;
    my $suffix      = $5;
    
    # Trim leading and trailing whitespace from prefix and suffix
    $prefix =~ s/\A\s+//;
    $prefix =~ s/\s+\z//;
    
    $suffix =~ s/\A\s+//;
    $suffix =~ s/\s+\z//;
    
    # If both prefix and suffix are non-empty, combine them with a
    # single space between; else, combine them without a space
    if ((length($prefix) > 0) and (length($suffix) > 0)) {
      $altered = "$prefix $suffix";
    } else {
      $altered = "$prefix$suffix";
    }
    
    # Set parse_ok flag
    $parse_ok = 1;
  }
  
  # We will be using vertical bar in pinyin keys, so make sure there is
  # no vertical bar already in the pinyin keys, clearing the parse_ok
  # flag if there is
  if ($parse_ok) {
    if ($pinyin_keys =~ /\|/) {
      $parse_ok = 0;
    }
  }
  
  # If parsing succeeded in previous step, then continue now with
  # unified parsing
  if ($parse_ok) {
    # Lowercase context to normalize it, but then replace beijing and
    # taiwan with capitalized variants
    $context =~ tr/A-Z/a-z/;
    if ($context eq 'beijing') {
      $context = 'Beijing';
    } elsif ($context eq 'taiwan') {
      $context = 'Taiwan';
    }
    
    # Whitespace-trim condition
    $condition =~ s/\A\s+//;
    $condition =~ s/\s+\z//;
    
    # Whitespace-trim pinyin keys, and also the opening and closing
    # square bracket
    $pinyin_keys =~ s/\A\s*\[\s*//;
    $pinyin_keys =~ s/\s*\]\s*\z//;
    
    # Replace any "] or [" junction in the Pinyin keys with a vertical
    # bar, which we already verified earlier is not already in the
    # Pinyin keys
    $pinyin_keys =~ s/\s*\]\s*or\s*\[\s*/\|/g;
    
    # If the last thing in the Pinyin keys is a vertical bar followed by
    # whitespace, then the syntax wasn't ok, so clear the parse flag in
    # that case
    if ($pinyin_keys =~ /\|\s*\z/) {
      $parse_ok = 0;
    }
  }
  
  # If parsing is still OK, then we need to get array of normalized
  # Pinyin alternatives
  my @pnys;
  if ($parse_ok) {
    for my $pny_raw (split /\|/, $pinyin_keys) {
      # Start by whitespace trimming
      $pny_raw =~ s/\A\s+//;
      $pny_raw =~ s/\s+\z//;
      
      # Something must remain else parsing fails
      unless (length($pny_raw) > 0) {
        $parse_ok = 0;
        last;
      }
      
      # Split into tokens around whitespace
      my @tks = split ' ', $pny_raw;
      ($#tks >= 0) or die "Unexpected";
      
      # Make sure each token is an ASCII letter, followed by zero or
      # more lowercase ASCII letters and colons, followed by a digit
      # 1-5
      for my $tk (@tks) {
        unless ($tk =~ /\A[A-Za-z][a-z:]*[1-5]\z/) {
          $parse_ok = 0;
          last;
        }
      }
      ($parse_ok) or last;
      
      # Rejoin with a single space between each syllable
      my $pny = join ' ', @tks;
      
      # Add to normalized Pinyin array
      push @pnys, ( $pny );
    }
  }
  
  # If parse_ok flag still set, define the result
  if ($parse_ok) {
    $result = [
      $altered,
      $context,
      \@pnys,
      $condition
    ];
  }
  
  # Return result or undef
  return $result;
}

=item B<extract_xref(str)>

Given a string containing a gloss, attempt to extract a cross-reference
annotation.

The given string must be a Unicode string.  Do not pass a binary string
that is encoded in UTF-8.

If the given string has a recognized cross-reference annotation within
it, then the return value is an array reference with five elements.

The first element is the gloss with the cross-reference annotation
removed.  This may be an empty string if the cross-reference annotation
was the only thing in the gloss.  If this element is an empty string,
then the cross-reference applies to the whole mpy entry.  If this
element is not empty, then the cross-reference applies just to this
particular gloss.

The second element is the descriptor string, or an empty string if there
is no descriptor.  This is an adjective that qualifies the type of
reference, such as I<erhua>, I<old>, I<archaic>, I<dialect>,
I<euphemistic>, or I<Taiwan>.

The third element is a string storing the type of cross-reference, which
is always present.  This could be I<variant of>, I<contraction of>,
I<used in>, I<abbr. for>, I<abbr. to>, I<see>, I<see also>, I<equivalent
to>, I<same as>, or I<also written>.  Note the difference between
I<abbr. for> and I<abbr. to>.  I<abbr. for> marks that this entry is the
abbreviated form and the refererenced entry is the full form.  I<abbr.
to> marks that this entry is the full form and the referenced entry is
the abbreviated form.

The fourth element is an array reference to a subarray storing further
array references specifying the actual cross-references.  The
cross-reference sub-subarrays are either two string elements, the Han
traditional reading and the Han simplified reading, or three string
elements, the Han traditional reading, the Han simplified reading, and
the Pinyin.  If traditional and simplified readings are the same, both
elements will have the same value.  Pinyin is normalized to no leading
or trailing whitespace, exactly one space between syllables, and each
syllable is an ASCII letter, followed by zero or more ASCII lowercase
letters and colons, followed by a decimal digit 1-5.

The fifth element is a suffix, which is empty if there is no suffix.
This clarifies what is at the cross-referenced entry, or provides other
additional information.

If no cross-reference annotation could be found in the given entry, then
this function returns C<undef>.

=cut

sub extract_xref {
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";

  # Go through all parentheticals that don't have any nested
  # parentheticals within them and recursively check if any of them
  # contain a cross-reference; if they do, then that's the
  # cross-reference we want to return, along with an altered gloss that
  # drops that parenthetical
  while ($str =~ /\(([^\(\)]*)\)/g) {
    # Get current match
    my $match = $1;

    # Get start of current parenthetical and its length (including the
    # surrounding parentheses
    my $paren_len   = length($match) + 2;
    my $paren_start = pos($str) - $paren_len;
  
    # Recursively try to parse as a cross-reference
    my $retval = extract_xref(substr(
                                $str,
                                $paren_start + 1,
                                $paren_len - 2));
    if (defined $retval) {
      # We got a cross-reference in this parenthetical; get the prefix
      # and suffix before and after this parenthetical
      my $prefix = substr($str, 0, $paren_start);
      my $suffix = substr($str, $paren_start + $paren_len);
     
      # Whitespace-trim prefix and suffix
      $prefix =~ s/\A\s+//;
      $prefix =~ s/\s+\z//;
      $suffix =~ s/\A\s+//;
      $suffix =~ s/\s+\z//;
      
      # If both prefix or suffix are non-empty after trimming, join with
      # a space for the altered gloss, else join without space
      my $altered;
      if ((length($prefix) > 0) and (length($suffix) > 0)) {
        $altered = "$prefix $suffix";
      } else {
        $altered = "$prefix$suffix";
      }
      
      # Adjust the returned cross-reference with the altered gloss
      $retval->[0] = $altered;
      
      # Return the cross-reference with altered gloss
      return $retval;
    }
  }

  # We've just handled the parenthetical cases recursively, so now we
  # just need to worry about the whole entry being a cross-reference;
  # begin by trimming whitespace
  $str =~ s/\A\s+//;
  $str =~ s/\s+\z//;
  
  # If string contains SUB or ESC control codes, return undef since it
  # is not a valid xref in that case
  if ($str =~ /[\x{1a}\x{1b}]/) {
    return undef;
  }
  
  # Extract up to two cross-reference links from the string, replacing
  # the first with SUB and the second with ESC; if more than two, then
  # not valid xref and return undef; if less than one, then not valid
  # xref and return undef
  my @xrefa;
  my @xrefloc;
  while ($str =~ /(
                    [\p{Lo}]+
                    (?:\|[\p{Lo}]+)?
                    (?:
                      \s*
                      \[
                      [^\[\]]*
                      \]
                    )?
                  )/gx) {
    # We found a cross-reference link; get its text
    my $xref_text = $1;

    # Get the location of the link within the string
    my $xref_pos = pos($str) - length($xref_text);
    my $xref_len = length($xref_text);
    
    # If we already have two links, return undef
    unless ($#xrefa < 1) {
      return undef;
    }
    
    # Add this link to the arrays
    push @xrefa, ($xref_text);
    push @xrefloc, ([$xref_pos, $xref_len]);
  }
  
  unless ($#xrefa >= 0) {
    return undef;
  }
  
  for(my $i = $#xrefloc; $i >= 0; $i--) {
    # Determine replacement code
    my $rep_code;
    if ($i == 1) {
      $rep_code = "\x{1b}";
    } elsif ($i == 0) {
      $rep_code = "\x{1a}";
    } else {
      die "Unexpected";
    }
    
    # We are going in reverse order; replace the link with the
    # replacement code
    substr($str, $xrefloc[$i]->[0], $xrefloc[$i]->[1]) = $rep_code;
  }
  
  # Apply replacement of alternate pattern
  $str =~ s/
          \A
          \s*
          abbr\.
          \s+
          for
          \s+
          (
            [^\x{1a}\x{1b},\s]
            (?:
              [^\x{1a}\x{1b},]*
              [^\x{1a}\x{1b},\s]
            )?
          )
          ,?
          \s*\x{1a}\s*
          (
            (?:
              ,
              \s*
              [^\x{1a}\x{1b}]*
            )?
          )
          \s*
          \z
          /abbr. for \x{1a}, $1$2/xgi;
  
  # Apply normalizing substitutions
  $str =~ s/
          \A
          \s*
          \(Tw\)
          \s+
          abbr\.
          \s+
          for
          \s+
          (.*)
          \z
          /Taiwan abbr\. for $1/xgi;
  
  $str =~ s/
          \A
          \s*
          \(Tw\)
          \s+
          variant
          \s+
          of
          \s+
          (.*)
          \z
          /Taiwan variant of $1/xgi;
  
  $str =~ s/
          \A
          \s*
          Taiwanese
          \s+
          term
          \s+
          for
          \s+
          (.*)
          \z
          /Taiwan variant of $1/xgi;
  
  $str =~ s/
          \A
          \s*
          old
          \s+
          form
          \s+
          of
          \s+
          modern
          \s+
          (.*)
          \z
          /old variant of $1/xgi;
  
  $str =~ s/
          \A
          \s*
          dialectal
          \s+
          equivalent
          \s+
          of
          \s+
          (.*)
          \z
          /dialect variant of $1/xgi;
  
  $str =~ s/
          \A
          \s*
          equivalent
          \s+
          of
          \s+
          (.*)
          \z
          /equivalent to $1/xgi;
  
  $str =~ s/
          \A
          \s*
          abbr\.
          \s+
          of
          \s+
          (.*)
          \z
          /abbr. for $1/xgi;
  
  $str =~ s/
          \A
          \s*
          equivalent
          \s+
          to
          \s+
          \x{1a}
          \s*
          :
          (.*)
          \z
          /equivalent to \x{1a}, $1/xgi;
  
  $str =~ s/
          \A
          \s*
          used
          \s+
          for
          \s+
          \x{1a}
          \s*
          \(in
          \s+
          Taiwan\)
          \s*
          \z
          /Taiwan variant of \x{1a}/xgi;
  
  $str =~ s/
          \A
          \s*
          also
          \s+
          written
          \s+
          \x{1a}
          \s*
          ,?
          \s*
          see
          \s+
          also
          \s+
          \x{1b}
          \s*
          \z
          /also written \x{1a} and \x{1b}/xgi;
  
  $str =~ s/
          \A
          \s*
          see
          \s+
          \x{1a}
          \s*
          ,?
          \s*
          \x{1b}
          \s*
          \z
          /see \x{1a} and \x{1b}/xgi;
  
  $str =~ s/
          \A
          \s*
          variant
          \s+
          of
          \s+
          \x{1a}
          \s+
          and
          \s+
          \x{1b}
          \s*
          \(old\)
          \s*
          \z
          /variant of \x{1a} and \x{1b}/xgi;
  
  $str =~ s/
          \A
          \s*
          equivalent
          \s+
          to
          \s+
          either
          \s+
          \x{1a}
          \s+
          or
          \s+
          \x{1b}
          \s*
          \z
          /equivalent to \x{1a} and \x{1b}/xgi;
  
  $str =~ s/
          \A
          \s*
          ([^,]*)
          ,
          \s+
          abbr\.
          \s+
          (?:of|for)
          \s+
          \x{1a}
          \s*
          \z
          /abbr\. for \x{1a}, $1/xgi;
  
  # Apply exceptional substitutions
  $str =~ s/
          \A
          \s*
          abbr\.
          \s+
          for
          \s+
          Xinjiang
          \s+
          \x{1a}
          \s+
          or
          \s+
          Singapore
          \s+
          \x{1b}
          \s*
          \z
/abbr\. for \x{1a} and \x{1b}, Xinjiang or Singapore \(resp\.\)/xgi;

  $str =~ s/
          \A
          \s*
          \(slang\)
          \s+
          alternative
          \s+
          term
          \s+
          for
          \s+
          \x{1a}
          ,
          \s+
          lottery
          \s*
          \z
          /slang variant of \x{1a}, lottery/xgi;
  
  # We've normalized all the alternate patterns now, so we are ready to
  # parse the normal form (with substitute character(s))
  unless ($str =~
/
  \A
  \s*
  (erhua|old|archaic|dialect|euphemistic|Taiwan|colloquial|slang)?
  \s*
  (variant|contraction|used|abbr\.|see|equivalent|same|also|contrasted)
  \s*
  (of|in|for|to|also|as|written|with)?
  \s*
  \x{1a}
  \s*
  (?:
    and
    \s*
    \x{1b}
  )?
  ,?
  (.*)
  \z
/xi) {
    return undef;
  }
  
  my $descriptor  = $1;
  my $type1       = $2;
  my $type2       = $3;
  my $suffix      = $4;
  
  # Normalize case of descriptor
  $descriptor =~ tr/A-Z/a-z/;
  if ($descriptor eq 'taiwan') {
    $descriptor = "Taiwan";
  }
  
  # Normalize case of types
  $type1 =~ tr/A-Z/a-z/;
  $type2 =~ tr/A-Z/a-z/;
  
  # Form full type string
  my $type_full = "$type1 $type2";
  $type_full =~ s/\A\s+//;
  $type_full =~ s/\s+\z//;
  
  # Whitespace-trim suffix
  $suffix =~ s/\A\s+//;
  $suffix =~ s/\s+\z//;
  
  # Now parse the cross-reference links
  my @xresult;
  for my $xa (@xrefa) {
    # Parse possible types
    if ($xa =~ /\A([\p{Lo}]+)\z/) {
      my $han_trad = $1;
      my $han_simp = $han_trad;
      
      # Add to links
      push @xresult, ([$han_trad, $han_simp]);
      
    } elsif ($xa =~ /\A([\p{Lo}]+)\|([\p{Lo}]+)\z/) {
      my $han_trad = $1;
      my $han_simp = $2;
      
      # Add to links
      push @xresult, ([$han_trad, $han_simp]);
      
    } elsif ($xa =~ /\A([\p{Lo}]+)\s*\[([^\]]+)\]\z/) {
      my $han_trad = $1;
      my $han_simp = $han_trad;
      my $pny_raw  = $2;
      
      # (Pinyin) Start by whitespace trimming
      $pny_raw =~ s/\A\s+//;
      $pny_raw =~ s/\s+\z//;
      
      # (Pinyin) Something must remain else parsing fails
      unless (length($pny_raw) > 0) {
        return undef;
      }
      
      # (Pinyin) Split into tokens around whitespace
      my @tks = split ' ', $pny_raw;
      ($#tks >= 0) or die "Unexpected";
      
      # Make sure each token is an ASCII letter, followed by zero or
      # more lowercase ASCII letters and colons, followed by a digit
      # 1-5
      for my $tk (@tks) {
        unless ($tk =~ /\A[A-Za-z][a-z:]*[1-5]\z/) {
          return undef;
        }
      }
      
      # (Pinyin) Rejoin with a single space between each syllable
      my $pny = join ' ', @tks;
      
      # Add to links
      push @xresult, ([$han_trad, $han_simp, $pny]);
      
    } elsif ($xa =~ /\A([\p{Lo}]+)\|([\p{Lo}]+)\s*\[([^\]]+)\]\z/) {
      my $han_trad = $1;
      my $han_simp = $2;
      my $pny_raw  = $3;
      
      # (Pinyin) Start by whitespace trimming
      $pny_raw =~ s/\A\s+//;
      $pny_raw =~ s/\s+\z//;
      
      # (Pinyin) Something must remain else parsing fails
      unless (length($pny_raw) > 0) {
        return undef;
      }
      
      # (Pinyin) Split into tokens around whitespace
      my @tks = split ' ', $pny_raw;
      ($#tks >= 0) or die "Unexpected";
      
      # Make sure each token is an ASCII letter, followed by zero or
      # more lowercase ASCII letters and colons, followed by a digit
      # 1-5
      for my $tk (@tks) {
        unless ($tk =~ /\A[A-Za-z][a-z:]*[1-5]\z/) {
          return undef;
        }
      }
      
      # (Pinyin) Rejoin with a single space between each syllable
      my $pny = join ' ', @tks;
      
      # Add to links
      push @xresult, ([$han_trad, $han_simp, $pny]);
      
    } else {
      
      return undef;
    }
  }

  # If we got all the way here, return the full result with empty
  # altered gloss
  return [
    '',
    $descriptor,
    $type_full,
    \@xresult,
    $suffix
  ];
}

=item B<tocfl_pinyin(str)>

Given a string containing Pinyin in TOCFL format, normalize it to
standard Pinyin and return the result.  Fatal errors occur if the passed
string is not in the expected TOCFL Pinyin format.

This function does not handle variant notation involving parentheses and
slashes, so you have to decompose TOCFL Pinyin containing parentheses or
slashes before passing it through this function.

The given string must be a Unicode string.  Do not pass a binary string
that is encoded in UTF-8.

=cut

sub tocfl_pinyin {
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  
  # If TOCFL Pinyin begins with an uppercase letter, normalize case of
  # that initial letter to lowercase
  if ($str =~ /\A([A-Z])(.*)\z/) {
    my $a = $1;
    my $b = $2;
    
    $a = lc($a);
    $str = $a . $b;
  }
  
  # Drop ZWSP, normalize variant lowercase a to ASCII a, and change
  # breve diacritics to caron diacritics
  $str =~ s/\x{200b}//g;
  
  $str =~ s/\x{251}/a/g;
  
  $str =~ s/\x{103}/ǎ/g;
  $str =~ s/\x{115}/ě/g;
  $str =~ s/\x{12d}/ǐ/g;
  $str =~ s/\x{14f}/ǒ/g;
  $str =~ s/\x{16d}/ǔ/g;
  
  # Correct TOCFL typos
  if (defined $PNY_TYPO{$str}) {
    $str = $PNY_TYPO{$str};
  }
  
  # Make sure only the allowed characters are used
  for my $c (split //, $str) {
    my $cpv = ord($c);
    ((($cpv >= ord('a')) and ($cpv <= ord('z'))) or
      ($c eq 'à') or ($c eq 'á') or
      ($c eq 'è') or ($c eq 'é') or
      ($c eq 'ì') or ($c eq 'í') or
      ($c eq 'ò') or ($c eq 'ó') or
      ($c eq 'ù') or ($c eq 'ú') or
      ($c eq 'ā') or ($c eq 'ē') or ($c eq 'ī') or
        ($c eq 'ō') or ($c eq 'ū') or
      ($c eq 'ǎ') or ($c eq 'ě') or ($c eq 'ǐ') or
        ($c eq 'ǒ') or ($c eq 'ǔ') or
      ($c eq 'ü') or ($c eq 'ǖ') or ($c eq 'ǘ') or
        ($c eq 'ǚ') or ($c eq 'ǜ')) or
      die "Invalid pinyin char, stopped";
  }
  
  # Make sure at least one character
  (length($str) > 0) or die "Empty Pinyin not allowed, stopped";
  
  # Keep a copy of the unaltered Pinyin
  my $unaltered = $str;
  
  # Change the digraph consonants to capitalized; that is to say,
  # zh -> Z, ch -> C, sh -> S; but leave ng alone for now because we
  # don't know yet when it is G and when it is two consonants
  $str =~ s/zh/Z/g;
  $str =~ s/ch/C/g;
  $str =~ s/sh/S/g;
  
  # Decompose the string into an array where the first element is a
  # string of only consonants, the second element is a string of only
  # vowels, the third element is a string of only consonants, and so
  # forth; elements may be empty strings
  my @cva;
  while(length($str) > 0) {
    # Based on current length of cva array, determine whether we need to
    # get consonants or vowels
    if ((scalar(@cva) % 2) == 0) {
      # First, third, fifth, etc. element, so we need as many consonants
      # as we can get from the start of the string
      if ($str =~ /\A([CSZb-df-hj-np-tv-z]+)/) {
        # We found a consonant sequence
        my $cs = $1;
        
        # Drop from start of string and add to array
        push @cva, ($cs);
        $str = substr($str, length($cs));
        
      } else {
        # No consonants at start of string, so push empty string
        push @cva, ('');
      }
      
    } else {
      # Second, fourth, sixth, etc. element, so we need as many vowels
      # as we can get from the start of the string
      if ($str =~ /\A([^CSZb-df-hj-np-tv-z]+)/) {
        # We found a vowel sequence
        my $vs = $1;
        
        # Drop from start of string and add to array
        push @cva, ($vs);
        $str = substr($str, length($vs));
        
      } else {
        # No vowels at start of string, so push empty string
        push @cva, ('');
      }
    }
    
    # Prevent an infinite loop by stopping if more than a thousand
    # elements in array
    (scalar(@cva) <= 1000) or die "Failed to parse Pinyin, stopped";
  }
  
  # Copy the array we just made to another array, except for each vowel
  # element, split so that only allowable multi-vowel sequences are
  # allowed; split vowel components will be separated from each other
  # by empty strings so that the consonant-vowel alternation is
  # preserved
  my @cvs;
  for(my $i = 0; $i <= $#cva; $i++) {
    # Check type of component
    if (($i % 2) == 0) {
      # Consonant component, so just copy to the new array
      push @cvs, ($cva[$i]);
      
    } else {
      # Vowel component, so get a copy
      my $vs = $cva[$i];
      
      # In special case of empty string, just copy an empty string over
      unless (length($vs) > 0) {
        push @cvs, ('');
        next;
      }
      
      # Our vowel sequence lookup table only has acute accent
      # diacritics, so make a copy of the vowel sequence where all tonal
      # diacritics are replaced by acute accent
      my $vsn = $vs;
      $vsn = NFD($vsn);
      $vsn =~ s/[\x{300}\x{304}\x{30c}]/\x{301}/g;
      $vsn = NFC($vsn);
      
      # Keep processing until the vowel sequence is empty
      my $first = 1;
      while (length($vs) > 0) {
        # Unless this is the first invocation, push an empty string
        # consonant separator
        if ($first) {
          $first = 0;
        } else {
          push @cvs, ('');
        }
        
        # Using the vowel sequence copy where all tonal diacritics are
        # acute accents, determine the longest matching sequence vowel
        # combination at the start of the vowel sequence
        my $seqlen = $MAX_VSEQ;
        if ($seqlen > length($vs)) {
          $seqlen = length($vs);
        }
        while ($seqlen > 1) {
          if (defined $PNY_MULTI{substr($vsn, 0, $seqlen)}) {
            last;
          } else {
            $seqlen--;
          }
        }
        
        # Push the next vowel combination onto the array and remove from
        # both sequence strings
        push @cvs, (substr($vs, 0, $seqlen));
        $vs  = substr($vs , $seqlen);
        $vsn = substr($vsn, $seqlen);
      }
    }
  }
  
  # Remove any empty sequence strings from the end of the array; this
  # shouldn't cause the array to go empty
  while ($#cvs >= 0) {
    if (length($cvs[$#cvs]) < 1) {
      pop;
    } else {
      last;
    }
  }
  ($#cvs >= 0) or die "Unexpected";
  
  # Go through all consonant sequences and split any r consonants into
  # either "r" (initial), "R" (final), or "Q" (erhua inflection)
  for(my $i = 0; $i <= $#cvs; $i = $i + 2) {
    # Get current consonant block
    my $cb = $cvs[$i];
    
    # Skip this consonant block if it doesn't have an "r"
    ($cb =~ /r/) or next;
    
    # If r is last consonant in block AND there is a vowel block
    # following this, then temporarily change it to "9" (which will
    # later be changed back to "r"
    if (($cb =~ /r\z/) and ($i < $#cvs)) {
      $cb =~ s/r\z/9/;
    }
    
    # If r is the first consonant in block and it wasn't handled by the
    # previous case AND there is a preceding vowel block AND it contains
    # just an e (any tone), then we might have an erhua
    if (($cb =~ /\Ar/) and ($i > 0) and
          ($cvs[$i - 1] =~ /\A[eēéěè]\z/)) {
      # Determine whether the preceding vowel block has a forced initial
      my $forced_initial = 0;
      
      if (($i == 2) and (length($cvs[0]) > 0)) {
        # Vowel block is very first and initial consonant sequence is
        # non-empty, so forced initial
        $forced_initial = 1;
      
      } else {
        # Other check for forced initial requires examination of
        # preceding consonant block
        my $pcb = $cvs[$i - 2];
        
        # Only possible for forced initial in this case if preceding
        # consonant block is not just "ng"
        unless ($pcb eq 'ng') {
          # Forced initial if at least two consonants or one consonant
          # other than n
          if (length($pcb) > 1) {
            $forced_initial = 1;
          } elsif ((length($pcb) == 1) and ($pcb ne 'n')) {
            $forced_initial = 1;
          }
        }
      }
      
      # If the preceding solitary e does not have a forced initial, then
      # we can change the r to R (final r)
      unless ($forced_initial) {
        $cb =~ s/\Ar/R/;
      }
    }
    
    # If r is the last consonant in block, we haven't handled it yet
    # with the other cases, and this consonant block is the very last
    # block in the word, then replace it with erhua inflection (Q)
    if (($cb =~ /r\z/) and ($i == $#cvs)) {
      $cb =~ s/r\z/Q/;
    }
    
    # There shouldn't be any r remaining in the consonant block after
    # applying these r->9, r->R, and r->Q replacements
    (not ($cb =~ /r/)) or die "Invalid Pinyin, stopped";
    
    # Replace the temporary "9" with "r" meaning initial r
    $cb =~ s/9/r/g;
    
    # Update consonant block
    $cvs[$i] = $cb;
  }
  
  # Go through all consonant sequences and convert any "ng" pairs either
  # to G (representing single NG final) or to "Ng" (representing final
  # N followed by initial G)
  for(my $i = 0; $i <= $#cvs; $i = $i + 2) {
    # Get current consonant block
    my $cb = $cvs[$i];
    
    # Skip this consonant block if it doesn't have an "ng"
    ($cb =~ /ng/) or next;
  
    # If this consonant block has anything more than "ng" in it, convert
    # ng to G (representing NG final) and then store this as the updated
    # value
    unless ($cb eq 'ng') {
      $cb =~ s/ng/G/g;
      $cvs[$i] = $cb;
      next;
    }
    
    # If we got here, the consonant block is "ng" so we need to
    # determine if it is "G" or "Ng"; if this consonant block is the
    # very first block or the very last block, or either of the
    # surrounding vowel blocks are empty, then set update this consonant
    # block to "G"
    if (($i == 0) or ($i == $#cvs) or
          (length($cvs[$i - 1]) < 1) or (length($cvs[$i + 1]) < 1)) {
      $cvs[$i] = 'G';
      next;
    }
    
    # If we got here, we have "ng" surrounded by vowels; this is Ng
    # except for the exceptional cases, which are G
    if (defined $NG_EXCEPTION{$unaltered}) {
      $cvs[$i] = 'G';
    } else {
      $cvs[$i] = 'Ng';
    }
  }
  
  # Go through all consonant sequences and convert any "n" that hasn't
  # been handled by the "ng" process above to either "n" (representing
  # an initial) or "N" (representing a final)
  for(my $i = 0; $i <= $#cvs; $i = $i + 2) {
    # Get current consonant block
    my $cb = $cvs[$i];
    
    # Skip this consonant block if it doesn't have an "n"
    ($cb =~ /n/) or next;
    
    # Shouldn't have an ng since we already handled that
    (not ($cb =~ /ng/)) or die "Unexpected";
    
    # If n is first letter in the whole word, convert to "9"
    # (placeholder for initial)
    if (($cb =~ /\An/) and ($i == 0)) {
      $cb =~ s/\An/9/;
    }
    
    # If n is last letter in the whole word, convert to "N"
    if (($cb =~ /n\z/) and ($i == $#cvs)) {
      $cb =~ s/n\z/N/;
    }
    
    # If n is not alone in a consonant sequence (not including the ng
    # case handled earlier), then convert n at the start of the sequence
    # to N and n at the end of the sequence to "9"
    if (length($cb) > 1) {
      $cb =~ s/\An/N/;
      $cb =~ s/n\z/9/;
    }
    
    # If n by itself in this consonant sequence and consonant sequence
    # surrounded by vowels, then convert to "9" unless it is in the
    # exception list, in which case convert to "N"
    if (($cb eq 'n') and ($i > 0) and ($i < $#cvs)) {
      if (defined $N_EXCEPTION{$unaltered}) {
        $cb = 'N';
      } else {
        $cb = '9';
      }
    }
    
    # Make sure no unconverted n's remain
    (not ($cb =~ /n/)) or die "Invalid Pinyin, stopped";
    
    # Replace the temporary "9" with "n" meaning initial n
    $cb =~ s/9/n/g;
    
    # Update consonant block
    $cvs[$i] = $cb;
  }
  
  # Go through consonant blocks one last time, this time assigning each
  # consonant to the proper surrounding vowel block
  for(my $i = 0; $i <= $#cvs; $i = $i + 2) {
    # Get current consonant block
    my $cb = $cvs[$i];
    
    # Block must be optional final, optional erhua, and optional initial
    ($cb =~ /\A([RGN]?)([Q]?)([pbtdkgmnczCZqjfsSxhlr]?)\z/) or
      die "Invalid Pinyin, stopped";
    
    my $final   = $1;
    my $erhua   = $2;
    my $initial = $3;
    
    # Now that we've split by position, convert the uppercase notation
    # back to standard notation for each
    if ($final eq 'R') {
      $final = 'r';
    } elsif ($final eq 'G') {
      $final = 'ng';
    } elsif ($final eq 'N') {
      $final = 'n';
    }
    
    if ($erhua eq 'Q') {
      $erhua = 'r';
    }
    
    if ($initial eq 'Z') {
      $initial = 'zh';
    } elsif ($initial eq 'C') {
      $initial = 'ch';
    } elsif ($initial eq 'S') {
      $initial = 'sh';
    }
    
    # Make sure final and erhua are not both 'r'
    (not (($final eq 'r') and ($erhua eq 'r'))) or
      die "Invalid Pinyin, stopped";
    
    # If this is first, make sure final and erhua are both empty
    if ($i == 0) {
      ((length($final) < 1) and (length($erhua) < 1)) or
        die "Invalid Pinyin, stopped";
    }
    
    # If this is last, make sure initial is empty
    if ($i == $#cvs) {
      (length($initial) < 1) or die "Invalid Pinyin, stopped";
    }
    
    # Assign components to their proper syllables
    if (length($final) > 0) {
      $cvs[$i - 1] = $cvs[$i - 1] . $final;
    }
    
    if (length($erhua) > 0) {
      $cvs[$i - 1] = $cvs[$i - 1] . $erhua;
    }
    
    if (length($initial) > 0) {
      $cvs[$i + 1] = $initial . $cvs[$i + 1];
    }
  }
  
  # Vowel blocks now hold syllables; transfer to array
  my @syls;
  for(my $i = 1; $i <= $#cvs; $i = $i + 2) {
    push @syls, ($cvs[$i]);
  }
  ($#syls >= 0) or die "Unexpected";
  
  # Every syllable after the first must start with a consonant letter or
  # else an apostrophe is prefixed
  for(my $i = 1; $i <= $#syls; $i++) {
    unless ($syls[$i] =~ /\A[b-df-hj-np-tv-z]/) {
      $syls[$i] = "'" . $syls[$i];
    }
  }
  
  # Normalized result is all the syllables joined together
  return join '', @syls;
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
