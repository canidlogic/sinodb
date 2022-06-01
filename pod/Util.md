# NAME

Sino::Util - Utility functions for Sino.

# SYNOPSIS

    use Sino::Util qw(
          han_exmap
          pinyin_count
          han_count
          parse_measures
          extract_pronunciation
          extract_xref);
    
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

# DESCRIPTION

Provides various utility functions.  See the documentation of the
individual functions for further information.

# FUNCTIONS

- **han\_exmap(han)**

    Given a string containing a Han rendering, return the Pinyin reading of
    this Han character if this is an exceptional mapping, or else return
    undef if there is no known exception mapping for this Han rendering.

    In a couple of cases in the TOCFL data, it is difficult to decide which
    Han reading maps to which Pinyin reading using regular rules.  It is
    easier in this cases to use a lookup table for exceptions, which this
    function provides.

    If _all_ the Han readings of a word have exceptional mappings as
    returned by this function _and_ all the exceptional Pinyin returned by
    this function already exists as Pinyin readings for this word, then use
    the mappings returned by this function.  Otherwise, use regular rules
    for resolving how Han and Pinyin are mapped in the TOCFL dataset.

- **pinyin\_count(str)**

    Given a string containing TOCFL-formatted Pinyin, return the number of
    syllables within the string.

    The TOCFL data files contain some inconsistencies in the Pinyin
    renderings that this function expects were already cleaned up during by
    the `import_tocfl.pl` script.  No parentheses are allowed in the given
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

- **han\_count(str)**

    Given a string of a Han rendering, return the adjusted count of
    characters.  This is not always the same as the length of the string in
    codepoints!  The "adjusted" length is designed so that the count
    returned by this function can be directly compared to the count returned
    by the `pinyin_count` function.  In order to make this happen, a few
    Han characters with rhotic pronunciations that are not erhua must be
    counted twice, but only when they are the last character in the
    rendering.

- **parse\_measures(str)**

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
    then this function will return `undef` indicating the gloss is not a
    valid measures gloss.

    If the given string is not recognized as a gloss containing measure
    words, then `undef` is returned.

- **extract\_pronunciation(str)**

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
    is used.  The most generic value for this element is `also` which means
    an alternate pronunciation.  It can also be something specific like
    `Beijing` `Taiwan` `colloquially` `old` `commonly` and so forth.
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
    this function returns `undef`.

- **extract\_xref(str)**

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
    reference, such as _erhua_, _old_, _archaic_, _dialect_,
    _euphemistic_, or _Taiwan_.

    The third element is a string storing the type of cross-reference, which
    is always present.  This could be _variant of_, _contraction of_,
    _used in_, _abbr. for_, _abbr. to_, _see_, _see also_, _equivalent
    to_, _same as_, or _also written_.  Note the difference between
    _abbr. for_ and _abbr. to_.  _abbr. for_ marks that this entry is the
    abbreviated form and the refererenced entry is the full form.  _abbr.
    to_ marks that this entry is the full form and the referenced entry is
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
    this function returns `undef`.

# AUTHOR

Noah Johnson, `noah.johnson@loupmail.com`

# COPYRIGHT AND LICENSE

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
