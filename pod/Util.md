# NAME

Sino::Util - Utility functions for Sino.

# SYNOPSIS

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
