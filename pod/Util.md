# NAME

Sino::Util - Utility functions for Sino.

# SYNOPSIS

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
    
    # Find citations within a gloss
    my @cites = parse_cites($gloss);
    for my $cite (@cites) {
      my $starting_index = $cite->[0];
      my $cite_length    = $cite->[1];
      my $cite_trad      = $cite->[2];
      my $cite_simp      = $cite->[3];
      my $cite_pny;
      if (scalar(@$cite) >= 5) {
        $cite_pny = $cite->[4];
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

# DESCRIPTION

Provides various utility functions.  See the documentation of the
individual functions for further information.

# FUNCTIONS

- **parse\_multifield($str)**

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

    **Warning:** This function will not handle Bopomofo parentheticals
    correctly.  You must drop these from the TOCFL input before running it
    through this function.

- **parse\_measures(str)**

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
    normalized with cedict\_pinyin() and therefore be in standard Pinyin
    format.

    If the given string does not have any recognized measure-word gloss
    within it, then `undef` is returned.

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
    strings for the alternate pronunciation.  The Pinyin will have already
    been normalized by running it through cedict\_pinyin().  There will be at
    least one Pinyin string in the array.  If the Pinyin in the original
    gloss could not be normalized, this function will return `undef`.

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
    elements will have the same value.  Pinyin is normalized according to
    the function cedict\_pinyin().

    The fifth element is a suffix, which is empty if there is no suffix.
    This clarifies what is at the cross-referenced entry, or provides other
    additional information.

    If no cross-reference annotation could be found in the given entry, then
    this function returns `undef`.

- **parse\_cites(str)**

    Find and parse all citations within a given gloss.

    The given string is not modified.  The return value is an array in list
    context that identifies the location within the given string of each
    citation and its parsed representation.  If there are no recognized
    citations within the string, an empty array will be returned.

    If you do not want cross-references and such to be picked up as
    citations, you should extract them from the gloss before passing the
    gloss to this function.

    The returned array has one subarray reference for each citation found,
    given in the order they appear in the string.  The array may be empty.
    Each subarray has either four or five elements.  The first element is
    the offset within the string of the first character of the citation and
    the second element is the length of the citation within the string.  The
    third and fourth elements are the traditional and simplified Han
    renderings of the citation.  If the fifth element is present, it is a
    Pinyin reading, normalized according to `cedict_pinyin()`.

- **match\_pinyin(\\@hws, \\@pnys)**

    Intelligently match Pinyin readings to the proper headwords within the
    TOCFL data.

    hws is a reference to an array storing the headwords.  There must be at
    least one headword.  Each headword must be a string consisting of at
    least one character, and all characters must be in the Unicode core CJK
    block.

    pnys is a reference to an array storing the Pinyin to match to these
    headwords.  Each Pinyin must be a string in standard, normalized Pinyin
    form.  `pinyin_split()` will be called on each Pinyin element within
    this function, so there will be fatal errors if there are any invalid
    Pinyin strings in the array.  There must be at least one Pinyin string.

    The return value is an array in list context.  Each element of this
    returned array is an array reference representing a match.  Each match
    subarray contains two elements, the first being a string storing one of
    the headwords from the hws array and the second being an array reference
    to a non-empty array of Pinyin strings from pnys that match this
    particular headword.

    Fatal errors occur if there is any problem during the matching process.

- **pinyin\_split(str)**

    Given a string containing Pinyin in standard format, return an array in
    list context containing each of the syllables.

    Before you can use TOCFL or CC-CEDICT Pinyin with this function, you
    must normalize it with `tocfl_pinyin()` or `cedict_pinyin()`.

    Fatal errors occur if the Pinyin is not in the proper format.  You can
    therefore use this function to verify that Pinyin is valid.

    Erhua inflections are returned as a separate "syllable" that contains
    just `r` by itself.  However, non-erhua use of `r` as a final in the
    syllable `er` is properly returned as a syllable `er`.

    Apostrophes are _not_ included in the returned syllables.

- **tocfl\_pinyin(str)**

    Given a string containing Pinyin in TOCFL format, normalize it to
    standard Pinyin and return the result.  Fatal errors occur if the passed
    string is not in the expected TOCFL Pinyin format.

    This function does not handle variant notation involving parentheses and
    slashes, so you have to decompose TOCFL Pinyin containing parentheses or
    slashes before passing it through this function.

    The given string must be a Unicode string.  Do not pass a binary string
    that is encoded in UTF-8.

    The result is verified as valid Pinyin with `pinyin_split()` before
    returning it from this function.

- **cedict\_pinyin(str)**

    Given a string containing Pinyin in CC-CEDICT format, normalize it to
    standard Pinyin and return the result, or `undef` if the conversion
    failed.

    **Warning:** This function is _not_ able to normalize all the Pinyin
    that is actually used within CC-CEDICT.  In particular, Pinyin that
    contains Latin letters by themselves (for abbreviations), Pinyin for
    certain proper names or sayings that includes punctuation marks, Pinyin
    that includes the `xx` crossed-out notation, and Pinyin that includes
    syllabic `m` will fail normalization by this function.  This function
    is only designed for the "regular" Pinyin cases found in CC-CEDICT.

    Normalized results will always be in all lowercase, following standard
    Pinyin format.  CC-CEDICT uses capitalized Pinyin syllables to indicate
    proper names.  If you want to preserve this information, you should scan
    the original CC-CEDICT string for any uppercase ASCII letters.  There is
    no way to recover this information just from the normalized Pinyin
    returned by this function.

    The given string must be a Unicode string.  Do not pass a binary string
    that is encoded in UTF-8.

    The result is verified as valid Pinyin with `pinyin_split()` before
    returning it from this function.

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
