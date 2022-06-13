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
                  parse_multifield
                  parse_measures
                  extract_pronunciation
                  extract_xref
                  parse_cites
                  match_pinyin
                  pinyin_split
                  tocfl_pinyin
                  cedict_pinyin);

# Core dependencies
use Unicode::Normalize;

=head1 NAME

Sino::Util - Utility functions for Sino.

=head1 SYNOPSIS

  use Sino::Util qw(
        parse_multifield
        parse_measures
        extract_pronunciation
        extract_xref
        parse_cites
        match_pinyin
        pinyin_split
        tocfl_pinyin
        cedict_pinyin);
  
  # Parse a TOCFL field with multiple values into a list
  my @vals = parse_multifield($tocfl_field);
  
  # Parse a gloss containing classifier/measure words
  my $result = parse_measures($gloss);
  if (defined $result) {
    my $altered_gloss = $result->[0];
    my $measures      = $result->[1];
    if (length($altered_gloss) > 0) {
      # Measure word is for this specific altered gloss
      ...
    } else {
      # Measure word is annotation on major entry
      ...
    }
    for my $measure (@$measures) {
      my $measure_trad = $measure[$i]->[0];
      my $measure_simp = $measure[$i]->[1];
      my $measure_pny;
      if (scalar(@{$measure[$i]}) >= 3) {
        $measure_pny = $measure[$i]->[2];
      }
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
    for my $pinyin (@$pinyin_array) {
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
  
  # Parse gloss into citation array
  my @cites = parse_cites($gloss);
  for(my $i = 0; $i <= $#cites; $i++) {
    if (($i % 2) == 0) {
      my $literal_string = $cites[$i];
      ...
      
    } else {
      my $cite_trad = $cites[$i]->[0];
      my $cite_simp = $cites[$i]->[1];
      my $cite_pny;
      if (scalar(@{$cites[$i]}) >= 3) {
        $cite_pny = $cites[$i]->[2];
      }
      ...
    }
  }
  
  # Match headwords to Pinyin within TOCFL data
  my @matches = match_pinyin(\@hws, \@pnys);
  for my $match (@matches) {
    my $head_word = $match->[0];
    for my $pinyin (@{$match->[1]}) {
      ...
    }
  }
  
  # Parse standard Pinyin into a sequence of syllables
  my @syl = pinyin_split($pinyin);
  
  # Convert TOCFL-style Pinyin to standard Pinyin
  my $standard_pinyin = tocfl_pinyin($tocfl_pinyin);
  
  # Convert CC-CEDICT-style Pinyin to standard Pinyin
  my $standard_pinyin = cedict_pinyin($cedict_pinyin);
  if (defined $standard_pinyin) {
    ...
  }

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

# Hash representing the set of recognized Pinyin sequences of vowels.
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

# Hash representing the mapping of recognized Pinyin sequences of vowels
# without tonal diacritics to the same sequence of vowels with the acute
# accent diacritic.
#
# This is used to determine which vowel to place the tonal diacritic on
# when there is a sequence of multiple vowels.  It is used by the
# cedict_pinyin() function.
#
# This hash is derived from PNY_MULTI by matching all the diacritic
# forms with their non-diacritic forms.  It also contains all
# single-vowel forms.
#
my %PNY_TONAL = (
  'a'   => 'á',
  'e'   => 'é',
  'i'   => 'í',
  'o'   => 'ó',
  'u'   => 'ú',
  'ü'   => 'ǘ',
  'ai'  => 'ái',
  'ao'  => 'áo',
  'ei'  => 'éi',
  'ia'  => 'iá',
  'iao' => 'iáo',
  'ie'  => 'ié',
  'io'  => 'ió',
  'iu'  => 'iú',
  'ou'  => 'óu',
  'ua'  => 'uá',
  'üa'  => 'üá',
  'uai' => 'uái',
  'ue'  => 'ué',
  'üe'  => 'üé',
  'ui'  => 'uí',
  'uo'  => 'uó'
);

# Hash representing the mapping of recognized Pinyin sequences of vowels
# with the acute accent diacritic to the same sequence of vowels without
# tonal diacritics.
#
# This is the inverse mapping from %PNY_TONAL.
#
my %PNY_TONELESS = (
  'á'   => 'a',
  'é'   => 'e',
  'í'   => 'i',
  'ó'   => 'o',
  'ú'   => 'u',
  'ǘ'   => 'ü',
  'ái'  => 'ai',
  'áo'  => 'ao',
  'éi'  => 'ei',
  'iá'  => 'ia',
  'iáo' => 'iao',
  'ié'  => 'ie',
  'ió'  => 'io',
  'iú'  => 'iu',
  'óu'  => 'ou',
  'uá'  => 'ua',
  'üá'  => 'üa',
  'uái' => 'uai',
  'ué'  => 'ue',
  'üé'  => 'üe',
  'uí'  => 'ui',
  'uó'  => 'uo'
);

# Hash representing the mapping of recognized Pinyin sequences of vowels
# without tonal diacritics to arrays storing all the contexts in which
# that particular vowel sequence may be used.
#
# Unlike the other vowel mapping hashes, this hash also includes lone
# vowels (vowel sequences of length one).
#
# A "context" consists of an initial "w" or "y" (if present), the vowel
# sequence, and a final "n" "ng" or "r" (if present, but not including
# erhua inflections).
#
# EXCEPTION:  "ue" also has a context "ue" but only when used with an
# initial consonant "j" "q" or "x".
#
# This is used to check that vowel sequences are in valid contexts.
#
my %PNY_AGREE = (
  'a'   => ['a', 'ya', 'wa', 'an', 'yan', 'wan', 'ang', 'yang', 'wang'],
  'e'   => ['e', 'ye', 'en', 'wen', 'eng', 'weng', 'er'],
  'i'   => ['i', 'yi', 'yin', 'in', 'ying', 'ing'],
  'o'   => ['o', 'wo', 'ong', 'yong', 'yo'],
  'u'   => ['u', 'wu', 'yu', 'un', 'yun'],
  'ü'   => ['ü', 'ün'],
  'ai'  => ['ai', 'wai', 'yai'],
  'ao'  => ['ao', 'yao'],
  'ei'  => ['ei', 'wei'],
  'ia'  => ['ia', 'ian', 'iang'],
  'iao' => ['iao'],
  'ie'  => ['ie'],
  'io'  => ['iong'],
  'iu'  => ['iu'],
  'ou'  => ['ou', 'you'],
  'ua'  => ['ua', 'uan', 'yuan', 'uang'],
  'üa'  => ['üan'],
  'uai' => ['uai'],
  'ue'  => ['yue'],
  'üe'  => ['üe'],
  'ui'  => ['ui'],
  'uo'  => ['uo']
);

# Hash that maps erroneous TOCFL Pinyin to corrected versions.
#
# This handles a few typos where the tonal diacritic was placed on the
# wrong vowel, and one case of a missing letter.
#
# To query this hash, you must have already "cleaned up" the TOCFL
# Pinyin by converting any uppercase initial letter to lowercase,
# dropping ZWSPs, normalizing variant lowercase a to ASCII a, and
# changing breve diacritics to caron diacritics.
#
my %PNY_TYPO = (
  'piàolìang'  => 'piàoliàng',
  'bǐfāngshūo' => 'bǐfāngshuō',
  'shoúxī'     => 'shóuxī',
  'gōnjǐ'      => 'gōngjǐ'
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
# the match_pinyin function.
#
my %HAN_EX = (
  "\x{9019}\x{88E1}" => "zhèlǐ",
  "\x{9019}\x{88CF}" => "zhèlǐ",
  "\x{9019}\x{5152}" => "zhèr",
  "\x{90A3}\x{88E1}" => "nàlǐ",
  "\x{90A3}\x{88CF}" => "nàlǐ",
  "\x{90A3}\x{5152}" => "nàr",
  "\x{54EA}\x{88E1}" => "nǎlǐ",
  "\x{54EA}\x{88CF}" => "nǎlǐ",
  "\x{54EA}\x{5152}" => "nǎr"
);

=head1 FUNCTIONS

=over 4

=item B<parse_multifield($str)>

Parse a TOCFL field value containing possible alternate value notations
into a sequence of values.

The return value is an array in list context of all the decoded values.
If there is only one value, the array will be length one.  The returned
array will never be empty.

The first alternative value notation that is decoded is the ASCII
forward slash, which separates alternatives.  This function will also
recognize U+FF0F as a variant forward slash and treat it as if it were
a regular ASCII slash.

The second alternative value notation that is decoded is parentheses,
which include an optional sequence.  Either standard ASCII parentheses
or variant parentheses U+FF08 and U+FF09 may be used.

Both slashes and parentheticals may be used at the same time.

The returned list will have no duplicate values in it, even if the
passed field value would generate duplicate values if decoded as-is.
De-duplication checks are performed by this function and duplicates are
silently discarded.

Fatal errors occur if there is a parsing problem.

B<Warning:> This function will not handle Bopomofo parentheticals
correctly.  You must drop these from the TOCFL input before running it
through this function.

=cut

sub parse_multifield {
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  
  # Normalize variant forward slash into ASCII forward slash
  $str =~ s/\x{ff0f}/\//g;
  
  # Normalize variant parentheses into ASCII parentheses
  $str =~ s/\x{ff08}/\(/g;
  $str =~ s/\x{ff09}/\)/g;
  
  # Get the source array by splitting on slashes
  my @sa = split /\//, $str;
  
  # Define target array to be empty for now
  my @ta;
  
  # Go through each element in the source array and either copy as-is to
  # target array or split into two elements in target array; also, do
  # duplication checks so that duplicates are never inserted while
  # decoding
  for my $sv (@sa) {
    # Handle cases
    if ($sv =~ /\A
                  ([^\(\)]*)
                  \(
                  ([^\(\)]*)
                  \)
                  ([^\(\)]*)
                \z/x) {
      # Single parenthetical, so split into prefix optional suffix
      my $prefix = $1;
      my $option = $2;
      my $suffix = $3;
      
      # Whitespace-trim each
      $prefix =~ s/\A[ \t]+//;
      $prefix =~ s/[ \t]+\z//;
      
      $option =~ s/\A[ \t]+//;
      $option =~ s/[ \t]+\z//;
      
      $suffix =~ s/\A[ \t]+//;
      $suffix =~ s/[ \t]+\z//;
      
      # Make sure option is not empty after trimming
      (length($option) > 0) or
        die "Empty optional, stopped";
      
      # Make sure either prefix or suffix (or both) is non-empty
      ((length($prefix) > 0) or (length($suffix) > 0)) or
        die "Invalid optional, stopped";
      
      # Insert both without and with the optional, but only if not
      # already in the target array
      for my $iv ($prefix . $suffix, $prefix . $option . $suffix) {
        my $dup_found = 0;
        for my $dvc (@ta) {
          if ($iv eq $dvc) {
            $dup_found = 1;
            last;
          }
        }
        unless ($dup_found) {
          push @ta, ($iv);
        }
      }
      
    } elsif ($sv =~ /\A[^\(\)]*\z/) {
      # No parentheticals, so begin by whitespace trimming
      $sv =~ s/\A[ \t]+//;
      $sv =~ s/[ \t]+\z//;
      
      # Make sure after trimming not empty
      (length($sv) > 0) or
        die "Empty component, stopped";
      
      # Push into target array, but only if not already in the
      # target array
      my $dup_found = 0;
      for my $dvc (@ta) {
        if ($sv eq $dvc) {
          $dup_found = 1;
          last;
        }
      }
      unless ($dup_found) {
        push @ta, ($sv);
      }
      
    } else {
      # Other cases are invalid
      die "Invalid record, stopped";
    }
  }
  
  # Check that target array is not empty
  ($#ta >= 0) or die "Empty multifield, stopped";
  
  # Return the target array
  return @ta;
}

=item B<parse_measures(str)>

Given a string containing a gloss, attempt to extract a measure word
(classifier) gloss.

The given string must be a Unicode string.  Do not pass a binary string
that is encoded in UTF-8.

If the given string is wholly a classifier gloss or has a parenthetical
classifier gloss, then this function will return an array reference to
an array with two elements.  The first element is a string containing
the gloss with the measure-word gloss removed.  (This first element is
an empty string if the whole gloss is a classifier gloss.)  The second
element is another array reference to an array of one or more classifier
subarrays.

Classifier subarrays have two or three elements.  The first two elements
are always the traditional Han rendering of the measure word and the
simplified Han rendering of the measure word.  (If both traditional and
simplified are the same, the same string will be duplicated in both
elements.)  If there was Pinyin present in the classifier gloss, then it
will be the third element of this subarray, else the third element will
not be present.  If Pinyin is present, it will already have been
normalized with cedict_pinyin() and therefore be in standard Pinyin
format.

If the given string does not have any recognized measure-word gloss
within it, then C<undef> is returned.

=cut

sub parse_measures {
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  
  # If there is a parenthetical classifier gloss, then recursively
  # handle that
  if ($str =~ /\A(.*)(\(\s*CL\s*:[^\(\)]*\))(.*)\z/i) {
    # We got a parenthetical, so parse the string
    my $prefix = $1;
    my $island = $2;
    my $suffix = $3;
    
    # Whitespace-trim prefix and suffix
    $prefix =~ s/\A\s+//;
    $prefix =~ s/\s+\z//;
    
    $suffix =~ s/\A\s+//;
    $suffix =~ s/\s+\z//;
    
    # If both prefix and suffix are non-empty, altered gloss is the
    # prefix and suffix separated by space, otherwise altered gloss is
    # just the two next to each other
    my $altered;
    if ((length($prefix) > 0) and (length($suffix) > 0)) {
      $altered = "$prefix $suffix";
    } else {
      $altered = $prefix . $suffix;
    }
    
    # Trim leading and trailing whitespace and parentheses from the
    # parenthetical
    $island =~ s/\A\s*\(\s*//;
    $island =~ s/\s*\)\s*//;
    
    # Recursively attempt to parse the island
    my $retval = parse_measures($island);
    
    # If recursive parsing succeeded, then alter the recursive return
    # value to include the altered gloss without the parenthetical
    if (defined $retval) {
      $retval->[0] = $altered;
    }
    
    # Return the possibly altered recursive return value
    return $retval;
  }
  
  # No parenthetical case, so start with an undefined result
  my $result = undef;
  
  # Only proceed if we get a basic match on the format
  if ($str =~
        /\A
          \s*
          CL\s*:
          \s*
          (
            [\x{4e00}-\x{9fff}]+
            (?:[\|\x{ff5c}][\x{4e00}-\x{9fff}]+)?
            \s*
            (?:\[
            [^\[\],]+
            \])?
            (?:
              \s*
              ,
              \s*
              [\x{4e00}-\x{9fff}]+
              (?:[\|\x{ff5c}][\x{4e00}-\x{9fff}]+)?
              \s*
              (?:\[
              [^\[\],]+
              \])?
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
                        (?:[\|\x{ff5c}][\x{4e00}-\x{9fff}]+)?
                      )
                      \s*
                      (
                        (?:\[
                          [^\[\],]+
                        \])?
                      )
                      \s*
                    /x) or die "Unexpected";
      my $han_raw = $1;
      my $pny_raw = $2;
      
      # Get traditional and simplified Han readings
      my $han_trad;
      my $han_simp;
      if ($han_raw =~ /[\|\x{ff5c}]/) {
        my @ha = split /[\|\x{ff5c}]/, $han_raw;
        ($#ha == 1) or die "Unexpected";
        $han_trad = $ha[0];
        $han_simp = $ha[1];
        
      } else {
        $han_trad = $han_raw;
        $han_simp = $han_raw;
      }
      
      # Define has_pinyin to indicate whether pinyin is present, and the
      # variable to hold the pinyin if present
      my $has_pinyin = 0;
      my $pinyin;
      
      # If Pinyin not empty, parse it
      unless ($pny_raw =~ /\A\s*\z/) {
      
        # Non-empty Pinyin, so set flag
        $has_pinyin = 1;
      
        # Trim leading and trailing whitespace and square brackets from
        # Pinyin, and parsing fails if result is empty
        $pny_raw =~ s/\A\s*\[\s*//;
        $pny_raw =~ s/\s*\]\s*\z//;
        unless (length($pny_raw) > 0) {
          $parse_ok = 0;
          last;
        }
        
        # Attempt to normalize Pinyin
        $pinyin = cedict_pinyin($pny_raw);
        unless (defined $pinyin) {
          $parse_ok = 0;
          last;
        }
      }
      
      # Add to results
      if ($has_pinyin) {
        push @results, ([$han_trad, $han_simp, $pinyin]);
      } else {
        push @results, ([$han_trad, $han_simp]);
      }
    }

    # If parsing was OK, set the return result as a reference to the
    # results array
    if ($parse_ok) {
      $result = \@results;
    }
  }

  # If result is defined, then add an empty string as the altered gloss
  if (defined $result) {
    $result = ['', $result];
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
strings for the alternate pronunciation.  The Pinyin will have already
been normalized by running it through cedict_pinyin().  There will be at
least one Pinyin string in the array.  If the Pinyin in the original
gloss could not be normalized, this function will return C<undef>.

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
      
      # Attempt to normalize the Pinyin
      my $pny = cedict_pinyin($pny_raw);
      unless (defined $pny) {
        $parse_ok = 0;
        last;
      }
      
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
elements will have the same value.  Pinyin is normalized according to
the function cedict_pinyin().

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
      
      # (Pinyin) Attempt to normalize Pinyin
      my $pny = cedict_pinyin($pny_raw);
      unless (defined $pny) {
        return undef;
      }
      
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
      
      # (Pinyin) Attempt to normalize Pinyin
      my $pny = cedict_pinyin($pny_raw);
      unless (defined $pny) {
        return undef;
      }
      
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

=item B<parse_cites(str)>

Parse a given gloss into a citation array.

The return value is an array in list context of one or more elements.
The first, third, fifth, etc. elements will be literal strings.  The
second, fourth, sixth, etc. elements will be subarray references
defining citations.

Citation subarrays consist of two or three elements.  The first two
elements are the traditional and simplified Han renderings.  (If
traditional and simplified are the same, both of these will be the same
string.)  If the third element is present, it is a Pinyin reading,
normalized according to cedict_pinyin().

=cut

sub parse_cites {
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  
  # Look for all candidate citations within the string
  my @candidates;
  
  while ($str =~ /
            ([\x{4e00}-\x{9fff}]+
            (?:[\|\x{ff5c}][\x{4e00}-\x{9fff}]+)?
            (?:\[
            [^\[\]]+
            \])?)
              /gx) {
    my $citestr = $1;
    my $citepos = pos($str) - length($citestr);
    push @candidates, ([$citepos, $citestr]);
  }
  
  # Build the parsed citations list, each element containing the
  # position and length of citation in the original string and the
  # reference to the parsed citation subarray
  my @citelist;
  for my $rec (@candidates) {
    # Get current candidate string
    my $cstr = $rec->[1];
    
    # Parse candidate string
    ($cstr =~ /\A
            ([\x{4e00}-\x{9fff}]+)
            ((?:[\|\x{ff5c}][\x{4e00}-\x{9fff}]+)?)
            ((?:\[
            [^\[\]]+
            \])?)
              \z/x) or next;
    
    my $htrad = $1;
    my $hsimp = $2;
    my $pkey  = $3;
    
    # Trim leading and trailing whitespace and square brackets from the
    # Pinyin key
    $pkey =~ s/\A\s*\[\s*//;
    $pkey =~ s/\s*\]\s*\z//;
    
    # Attempt to normalize the Pinyin if present
    my $has_pinyin = 0;
    my $pinyin;
    
    if (length($pkey) > 0) {
      $has_pinyin = 1;
      $pinyin = cedict_pinyin($pkey);
      (defined $pinyin) or next;
    }
    
    # If simplified is present, drop the leading bar; else, copy the
    # traditional to the simplified
    if (length($hsimp) > 0) {
      $hsimp =~ s/\A[\|\x{ff5c}]//;
    } else {
      $hsimp = $htrad;
    }
    
    # If we got here, add to the citation list
    my $cite;
    if ($has_pinyin) {
      $cite = [$htrad, $hsimp, $pinyin];
    } else {
      $cite = [$htrad, $hsimp];
    }
    
    push @citelist, ([
      $rec->[0], length($rec->[1]), $cite
    ]);
  }
  
  # Start the results array empty
  my @results;
  
  # If there are no citations, just return a single-element array with
  # just the passed string and proceed no further
  if (scalar(@citelist) < 1) {
    push @results, ($str);
    return @results;
  }
  
  # At least one citation, so figure out what comes in the original
  # string after the very last citation
  my $trailer = substr(
                    $str,
                    $citelist[$#citelist]->[0]
                      + $citelist[$#citelist]->[1]);
  
  # Build the result array except for the trailer
  for(my $i = 0; $i <= $#citelist; $i++) {
    # Get the start of the preceding segment
    my $preceding_i = 0;
    if ($i > 0) {
      $preceding_i = $citelist[$i - 1]->[0] + $citelist[$i - 1]->[1];
    }
    
    # Get the segment preceding this citation
    my $segment = substr(
                    $str,
                    $preceding_i,
                    $citelist[$i]->[0] - $preceding_i);
    
    # Push the segment and then this citation
    push @results, ($segment, $citelist[$i]->[2]);
  }
  
  # Finally, push the trailer if it is not empty
  if (length($trailer) > 0) {
    push @results, ($trailer);
  }
  
  # Return results
  return @results;
}

=item B<match_pinyin(\@hws, \@pnys)>

Intelligently match Pinyin readings to the proper headwords within the
TOCFL data.

hws is a reference to an array storing the headwords.  There must be at
least one headword.  Each headword must be a string consisting of at
least one character, and all characters must be in the Unicode core CJK
block.

pnys is a reference to an array storing the Pinyin to match to these
headwords.  Each Pinyin must be a string in standard, normalized Pinyin
form.  C<pinyin_split()> will be called on each Pinyin element within
this function, so there will be fatal errors if there are any invalid
Pinyin strings in the array.  There must be at least one Pinyin string.

The return value is an array in list context.  Each element of this
returned array is an array reference representing a match.  Each match
subarray contains two elements, the first being a string storing one of
the headwords from the hws array and the second being an array reference
to a non-empty array of Pinyin strings from pnys that match this
particular headword.

Fatal errors occur if there is any problem during the matching process.

=cut

sub match_pinyin {
  # Get and check parameters
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  my $hr = shift;
  my $pr = shift;
  
  ((ref($hr) eq 'ARRAY') and (ref($pr) eq 'ARRAY')) or
    die "Wrong parameter types, stopped";
  
  ((scalar(@$hr) > 0) and (scalar(@$pr) > 0)) or
    die "Empty parameter arrays, stopped";
  
  # Define the hrl and prl arrays, which have the same number of
  # elements as hr and pr respectively and store the length in syllables
  # from pinyin_split() within prl (where erhua is counted as a separate
  # syllable) and the length in characters within hrl; this also checks
  # the array contents in the process
  my @hrl;
  my @prl;
  
  for my $hw (@$hr) {
    ($hw =~ /\A[\x{4e00}-\x{9fff}]+\z/) or
      die "Invalid headword, stopped";
    push @hrl, (length($hw));
  }
  
  for my $pny (@$pr) {
    my $plen = scalar(pinyin_split($pny));
    push @prl, ($plen);
  }
  
  # FIRST EXCEPTIONAL CASE =============================================
  
  # If there are the exact same number of Han and Pinyin renderings,
  # check for the special case where each element corresponds in length
  my $special_case = 0;
  if (scalar(@$hr) == scalar(@$pr)) {
    $special_case = 1;
    for(my $i = 0; $i < scalar(@$hr); $i++) {
      unless ($hrl[$i] == $prl[$i]) {
        $special_case = 0;
        last;
      }
    }
  }
  
  # If we got this first special case, just match each headword with the
  # corresponding pinyin and return that without proceeding further
  if ($special_case) {
    my @sresult;
    for(my $i = 0; $i < scalar(@$hr); $i++) {
      push @sresult, ([$hr->[$i], [ $pr->[$i] ] ]);
    }
    return @sresult;
  }
  
  # SECOND EXCEPTIONAL CASE ============================================
  
  # See if everything has an exceptional mapping
  $special_case = 1;
  for my $h (@$hr) {
    unless (defined $HAN_EX{$h}) {
      $special_case = 0;
      last;
    }
  }
  
  # If everything does have an exceptional mapping, check if the
  # exceptional mapping case applies
  if ($special_case) {
    # Get a hash of all Pinyin readings of this word and set each to a
    # value of zero
    my %pyh;
    for my $p (@$pr) {
      $pyh{$p} = 0;
    }
    
    # Check that all exceptional mappings are in the hash and set all of
    # the hash values to one
    for my $h (@$hr) {
      if (defined $pyh{$HAN_EX{$h}}) {
        $pyh{$HAN_EX{$h}} = 1;
        
      } else {
        $special_case = 0;
        last;
      }
    }
    
    # If special case flag still on, check finally that all values in
    # the hash have been set to one
    if ($special_case) {
      for my $v (values %pyh) {
        unless ($v) {
          $special_case = 0;
          last;
        }
      }
    }
  }
  
  # If we got the exceptional mapping case, just match each headword
  # with Pinyin from the exceptional mapping and return that
  if ($special_case) {
    my @sresult;
    for(my $i = 0; $i < scalar(@$hr); $i++) {
      push @sresult, ([$hr->[$i], [ $HAN_EX{$hr->[$i]} ] ]);
    }
    return @sresult;
  }
  
  # GENERAL CASE =======================================================
  
  # General case -- start a mapping with character/syllable length as
  # the key, and start out by setting the lengths of all Han renderings
  # as keys, with the value of each set to zero if there is a single Han
  # rendering with that length or one if there are multiple Han
  # renderings with that length
  my %lh;
  for(my $i = 0; $i < scalar(@$hr); $i++) {
    my $h   = $hr->[$i];
    my $key = "$hrl[$i]";
    if (defined $lh{$key}) {
      $lh{$key} = 1;
    } else {
      $lh{$key} = 0;
    }
  }
  
  # Get the length in syllables of each Pinyin rendering (counting erhua
  # r as a separate syllable), and for each verify that the length is
  # already in the length mapping and that the mapped value is zero or
  # one or three, then set the mapped value to two if it is one or three
  # if it is zero
  for(my $i = 0; $i < scalar(@$pr); $i++) {
    my $p         = $pr->[$i];
    my $syl_count = "$prl[$i]";
    
    # Now begin verification, first checking that there is a Han
    # rendering with the same length
    if (defined $lh{$syl_count}) {
      # Second, check cases
      if (($lh{$syl_count} == 0) or ($lh{$syl_count} == 3)) {
        # Only a single Han rendering of this length, so we can have
        # any number of Pinyin for it; always set to 3 after one is
        # found so we can make sure every Han record was matched
        $lh{$syl_count} = 3;
        
      } elsif ($lh{$syl_count} == 1) {
        # Multiple Han renderings of this length that haven't been
        # claimed yet, so claim them all
        $lh{$syl_count} = 2;
        
      } else {
        # Ambiguous mapping
        die "Pinyin match failed, ambiguity, stopped";
      }
      
    } else {
      # No Han rendering with matching length
      die "Pinyin match failed, no Han with length, stopped";
    }
  }
  
  # Make sure that every Han record was matched; all values in the
  # length hash should be either 2 or 3
  for my $v (values %lh) {
    (($v == 2) or ($v == 3)) or
      die "Pinyin matching failed, stranded Han, stopped";
  }
  
  # Build the result array in general case
  my @result;
  for(my $i = 0; $i < scalar(@$hr); $i++) {
    # Get current Han reading and its count
    my $hanr = $hr->[$i];
    my $hanc = $hrl[$i];

    # Accumulate all Pinyin that have the same count
    my @pys;
    for(my $j = 0; $j < scalar(@$pr); $j++) {
      my $p = $pr->[$j];
      if ($prl[$j] == $hanc) {
        push @pys, ($p);
      }
    }
    
    # Add the new record to result
    push @result, ([$hanr, \@pys ]);
  }
  
  # Return result array in general case
  return @result;
}

=item B<pinyin_split(str)>

Given a string containing Pinyin in standard format, return an array in
list context containing each of the syllables.

Before you can use TOCFL or CC-CEDICT Pinyin with this function, you
must normalize it with C<tocfl_pinyin()> or C<cedict_pinyin()>.

Fatal errors occur if the Pinyin is not in the proper format.  You can
therefore use this function to verify that Pinyin is valid.

Erhua inflections are returned as a separate "syllable" that contains
just C<r> by itself.  However, non-erhua use of C<r> as a final in the
syllable C<er> is properly returned as a syllable C<er>.

Apostrophes are I<not> included in the returned syllables.

=cut

sub pinyin_split {
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  
  # Pinyin may not be empty
  (length($str) > 0) or die "Empty Pinyin, stopped";
  
  # Make sure no capital ASCII letters are present
  (not ($str =~ /[A-Z]/)) or die "Capital letters in Pinyin, stopped";
  
  # Convert consonant digraphs ch zh sh ng to C Z S G; however, only
  # convert ng to G when the sequence is last in the word or it occurs
  # immediately before an initial consonant
  $str =~ s/ch/C/g;
  $str =~ s/zh/Z/g;
  $str =~ s/sh/S/g;
  
  $str =~ s/ng\z/G/g;
  $str =~ s/ng(['pbtdkgmnczCZqjfsSxhlrwy])/G$1/g;
  
  # Define results array
  my @results;
  
  # Keep reading syllables until we've exhausted the string
  my $first_syl = 1;
  while (length($str) > 0) {
    
    # First of all, if this is the very first syllable, make sure we
    # don't start with an apostrophe, and then add an apostrophe if we
    # start with a vowel, so we can handle all syllables the same way
    if ($first_syl) {
      # Clear first_syl flag
      $first_syl = 0;
      
      # Make sure no apostrophe at start
      (not ($str =~ /\A'/)) or
        die "First syllable may not start with apostrophe, stopped";
      
      # Get the first character and decompose it in Unicode
      my $first_char = substr($str, 0, 1);
      $first_char = NFD($first_char);
      
      # If decomposed form of first character starts with a vowel, then
      # prefix an apostrophe to the string so we can handle the first
      # syllable the same as the others
      if ($first_char =~ /\A[aeiou]/) {
        $str = "'$str";
      }
    }
    
    # Handle the special case of an er syllable where r followed by end
    # of string or an initial consonant
    if (($str =~ /\A'[ēéěèe]r\z/) or
          ($str =~ /\A'[ēéěèe]r['pbtdkgmnczCZqjfsSxhlrwy]/)) {
      # Transfer this syllable to results (without the apostrophe), then
      # loop back
      my $s = substr($str, 1, 2);
      push @results, ($s);
      $str = substr($str, 3);
      next;
    }
    
    # Parse a CV proto-syllable as the initial consonant (including w
    # and y) or apostrophe, followed by a sequence of one or more
    # non-consonants
    
    ($str =~ /\A
              (['pbtdkgmnczCZqjfsSxhlrwy])
              ([^CSZGb-df-hj-np-tv-z']+)
              (.*)
            \z/x) or die "Invalid syllable, stopped";
    
    my $initial = $1;
    my $medial  = $2;
    my $rstr    = $3;
    
    # If the remaining string starts with G, or it starts with n that
    # is followed either by end of string or an initial consonant, then
    # transfer this leading character to the final consonant position
    # within the current syllable; else, leave the final consonant
    # position empty
    my $final = '';
    if ($rstr =~ /\AG/) {
      $final = 'G';
      $rstr = substr($rstr, 1);
      
    } elsif (($rstr =~ /\An\z/) or
              ($rstr =~ /\An['pbtdkgmnczCZqjfsSxhlrwy]/)) {
      $final = 'n';
      $rstr = substr($rstr, 1);
    }
    
    # Update string with everything after the syllable we decoded
    $str = $rstr;
    
    # Get the medial without any tonal diacritic
    my $medial_toneless;
    if ($medial =~ /\A[aeiouü]+\z/) {
      # No tonal diacritics present, so just copy the medial
      $medial_toneless = $medial;
      
    } else {
      # Tonal diacritics may be present, so begin by making a copy
      $medial_toneless = $medial;
      
      # Decompose to NFD
      $medial_toneless = NFD($medial_toneless);
      
      # Replace all tonal diacritics with acute accent
      $medial_toneless =~ s/\x{304}/\x{301}/g;
      $medial_toneless =~ s/\x{30c}/\x{301}/g;
      $medial_toneless =~ s/\x{300}/\x{301}/g;
      
      # Recompose to NFC
      $medial_toneless = NFC($medial_toneless);
      
      # Make sure this is a recognized tonal sequence
      (defined $PNY_TONELESS{$medial_toneless}) or
        die "Invalid Pinyin tonal medial, stopped";
      
      # Now get the toneless version of the medial
      $medial_toneless = $PNY_TONELESS{$medial_toneless};
    }
    
    # Make sure that toneless medial is recognized
    (defined $PNY_TONAL{$medial_toneless}) or
      die "Invalid Pinyin medial, stopped";
    
    # Get the vowel context, which is toneless medial, with the final
    # consonant suffixed (if present), and the initial consonant
    # prefixed if it is w or y
    my $vctx = $medial_toneless . $final;
    if ($initial =~ /\A[wy]\z/) {
      $vctx = $initial . $vctx;
    }
    
    # Convert G in vowel context back to ng
    $vctx =~ s/G/ng/g;
    
    # Check whether the vowel context is in the recognized set for this
    # medial
    my $context_ok = 0;
    
    (defined $PNY_AGREE{$medial_toneless}) or die "Unexpected";
    for my $cx (@{$PNY_AGREE{$medial_toneless}}) {
      if ($cx eq $vctx) {
        $context_ok = 1;
        last;
      }
    }
    
    # If vowel context wasn't found, check for the exceptional case of
    # a context "ue" when initial is "j" "q" or "x"
    unless ($context_ok) {
      if (($vctx eq 'ue') and ($initial =~ /\A[jqx]\z/)) {
        $context_ok = 1;
      }
    }
    
    # At this point, we can verify the vowel context is OK
    ($context_ok) or die "Invalid Pinyin vowel context $vctx, stopped";
    
    # Assemble the syllable (without any initial apostrophe), convert
    # digraph notation back to standard, and add it to the results
    my $assembly = $medial . $final;
    if ($initial ne "'") {
      $assembly = $initial . $assembly;
    }
    
    $assembly =~ s/C/ch/g;
    $assembly =~ s/Z/zh/g;
    $assembly =~ s/S/sh/g;
    $assembly =~ s/G/ng/g;
    
    push @results, ($assembly);
    
    # If the updated string starts with an r that is followed by end of
    # string OR an r followed by an initial consonant, then transfer
    # this r by itself as a syllable to the results, as an erhua
    # inflection
    if (($str =~ /\Ar\z/) or 
          ($str =~ /\Ar['pbtdkgmnczCZqjfsSxhlrwy]/)) {
      push @results, ('r');
      $str = substr($str, 1);
    }
  }
  
  # If we got here, return the results array
  return @results;
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

The result is verified as valid Pinyin with C<pinyin_split()> before
returning it from this function.

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
    ($cb =~ /\A([RGN]?)([Q]?)([pbtdkgmnczCZqjfsSxhlryw]?)\z/) or
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
  my $norm_result = join '', @syls;
  
  # Check that normalized result is valid by testing a pinyin_split
  # operation and then return it
  pinyin_split($norm_result);
  return $norm_result;
}

=item B<cedict_pinyin(str)>

Given a string containing Pinyin in CC-CEDICT format, normalize it to
standard Pinyin and return the result, or C<undef> if the conversion
failed.

B<Warning:> This function is I<not> able to normalize all the Pinyin
that is actually used within CC-CEDICT.  In particular, Pinyin that
contains Latin letters by themselves (for abbreviations), Pinyin for
certain proper names or sayings that includes punctuation marks, Pinyin
that includes the C<xx> crossed-out notation, and Pinyin that includes
syllabic C<m> will fail normalization by this function.  This function
is only designed for the "regular" Pinyin cases found in CC-CEDICT.

Normalized results will always be in all lowercase, following standard
Pinyin format.  CC-CEDICT uses capitalized Pinyin syllables to indicate
proper names.  If you want to preserve this information, you should scan
the original CC-CEDICT string for any uppercase ASCII letters.  There is
no way to recover this information just from the normalized Pinyin
returned by this function.

The given string must be a Unicode string.  Do not pass a binary string
that is encoded in UTF-8.

The result is verified as valid Pinyin with C<pinyin_split()> before
returning it from this function.

=cut

sub cedict_pinyin {
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  
  # Trim leading and trailing whitespace, failing if the result is empty
  $str =~ s/\A\s+//;
  $str =~ s/\s+\z//;
  (length($str) > 0) or return undef;
  
  # Split into one or more syllables separated by whitespace
  my @syls = split ' ', $str;
  ($#syls >= 0) or die "Unexpected";
  
  # Check that each syllable is an ASCII letter, followed by zero or
  # more ASCII letters and colons, followed by a decimal digit 1-5, and
  # check also that colon is only used immediately after the letter U
  for my $s (@syls) {
    ($s =~ /\A[a-z][a-z:]*[1-5]\z/i) or return undef;
    (not ($s =~ /[^uU]:/)) or return undef;
  }
  
  # Make everything lowercase and then convert u: to u-umlaut
  for my $s (@syls) {
    $s =~ tr/A-Z/a-z/;
    $s =~ s/u:/ü/g;
    (not ($s =~ /:/)) or die "Unexpected";
  }
  
  # Convert everything to a parsed array @mps where each element is a
  # subarray of five elements:  initial consonant (including w/y, empty
  # string also allowed), vowel sequence, final consonant (empty string
  # allowed), erhua ('r' or empty string), and integer tone number 1-5
  my @mps;
  for(my $i = 0; $i <= $#syls; $i++) {
    # Parse this syllable
    ($syls[$i] =~
        /\A
          ((?:b|d|g|p|t|k|m|n|z|zh|j|c|ch|q|f|s|sh|x|h|l|r|y|w)?)
          ([aeiouü]+)
          ((?:n|ng|r)?)
          ([1-5])
        \z/x) or return undef;
    
    my $initial = $1;
    my $vseq    = $2;
    my $final   = $3;
    my $tone    = int($4);
    
    # If final is r, make sure vseq is "e" and initial is empty; else,
    # if final is not r, check whether next syllable is an erhua that
    # we should incorporate here
    my $erhua = '';
    if ($final eq 'r') {
      # Check structure around final "r"
      ($vseq eq 'e') or return undef;
      (length($initial) < 1) or return undef;
      
    } else {
      # Final is not "r", so check if next syllable is erhua, and
      # incorporate it into this syllable if it is
      if ($i < $#syls) {
        if ($syls[$i + 1] eq 'r5') {
          $erhua = 'r';
          $i++;
        }
      }
    }
    
    # Figure out the vowel context
    my $vctx = $vseq . $final;
    if (($initial eq 'w') or ($initial eq 'y')) {
      $vctx = $initial . $vctx;
    }

    # Check whether this context is recognized for this vowel sequence
    my $valid_context = 0;
    (defined $PNY_AGREE{$vseq}) or die "Unexpected";
    for my $vc (@{$PNY_AGREE{$vseq}}) {
      if ($vc eq $vctx) {
        $valid_context = 1;
        last;
      }
    }
    
    # If we didn't find a valid context, check for the exceptional case
    # where the vowel sequence is "ue", the context is "ue", and the
    # initial consonant is "j" "q" or "x"
    unless ($valid_context) {
      if (($vseq eq 'ue') and ($vctx eq 'ue') and
            (($initial eq 'j') or ($initial eq 'q') or
                ($initial eq 'x'))) {
        $valid_context = 1;
      }
    }
    
    # Make sure vowel sequence is valid in context
    ($valid_context) or return undef;
    
    # If initial consonant is labial, make sure vowel sequence is not
    # "uo" (it should always be changed to "o" in this case)
    if ($initial =~ /\A[bpmf]\z/) {
      (not ($vseq eq 'uo')) or return undef;
    }
    
    # If initial consonant is alveolo-palatal, make sure vowel sequence
    # does not begin with u-umlaut (it should always be changed to plain
    # u in this case)
    if ($initial =~ /\A[jqx]\z/) {
      (not ($vseq =~ /\Aü/)) or return undef;
    }
    
    # Push parsed representation of syllable
    push @mps, ([
      $initial, $vseq, $final, $erhua, $tone
    ]);
  }
  
  # Assemble all the syllables in standard Pinyin
  my @results;
  for my $rec (@mps) {
    # Get parsed representation
    my $initial = $rec->[0];
    my $vowel   = $rec->[1];
    my $final   = $rec->[2];
    my $erhua   = $rec->[3];
    my $tone    = $rec->[4];
    
    # If this is not the very first syllable AND the initial is empty,
    # set it to an apostrophe
    if (($#results >= 0) and (length($initial) < 1)) {
      $initial = "'";
    }
    
    # If tone is not 5, then we need to add a diacritic to the vowel
    # sequence
    unless ($tone == 5) {
      # Determine the proper combining diacritic
      my $dia;
      if ($tone == 1) {
        $dia = "\x{304}";
        
      } elsif ($tone == 2) {
        $dia = "\x{301}";
        
      } elsif ($tone == 3) {
        $dia = "\x{30c}";
        
      } elsif ($tone == 4) {
        $dia = "\x{300}";
        
      } else {
        die "Unexpected";
      }
      
      # Replace vowel sequence with acute accent diacritic sequence
      (defined $PNY_TONAL{$vowel}) or die "Unexpected";
      $vowel = $PNY_TONAL{$vowel};
      
      # If desired diacritic is something other than acute accent,
      # replace the acute accent with proper mark
      unless ($dia eq "\x{301}") {
        $vowel = NFD($vowel);
        $vowel =~ s/\x{301}/$dia/g;
        $vowel = NFC($vowel);
      }
    }
    
    # Add this syllable to results
    push @results, ($initial . $vowel . $final . $erhua);
  }
  
  # Normalized result is all the syllables joined together
  my $norm_result = join '', @results;
  
  # Check that normalized result is valid by testing a pinyin_split
  # operation and then return assembled result
  pinyin_split($norm_result);
  return $norm_result;
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
