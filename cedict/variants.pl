#!/usr/bin/env perl
use strict;
use warnings;

# Dict modules
use Dict::Parse;
use Dict::Util;
use DictConfig;

=head1 NAME

variants.pl - Scan the dictionary to verify variant reference format.

=head1 SYNOPSIS

  ./variants.pl

=head1 DESCRIPTION

Scans through all glosses in all records in the dictionary.  For each
gloss, defines two properties.  The first property, C<has_variant> is
set to true if there is a case-insensitive match for C<variant of>
anywhere within the gloss (where the internal space can be any sequence
of one or more whitespace characters).  This script will also make sure
that there is no single gloss where C<variant of> occurs more than once.

The second property, C<has_variant_ref> is set to true if one of the
recognized variant reference formats is detected within the gloss.  All
variant reference formats include C<variant of> within them, so there
should never be a time when <has_variant> is true but C<has_variant_ref>
is false.  (The script verifies this.)

This script will report the line numbers of all records that contain
glosses where C<has_variant> is true but C<has_variant_ref> is false,
indicating that the text C<variant of> appears in the gloss but no
variant reference was recognized.  This is OK sometimes, because
C<variant of> could possibly occur in other contexts within glosses.
You should go through all the given exception records printed out by
this script and make sure that no major variant references were missed.

(With the current version of the dataset, only six records are found by
this script.  These are three cases where C<variant of> is indeed not
referring to an actual variant reference, and three cases where there
is some sort of odd variant reference.  Each of these three odd variant
references involve dialectical variants of geographical names, so we
can ignore them.)

This script requires the C<Dict::Parse> module, so see that module for
how to set up an appropriate configuration file and so forth.

=head2 Variant reference formats

The detection code is implemented in the C<variants> function of the
C<Dict::Util> module.  This section describes the format of variant
references.

All recognized variant references begin with the following:

=over 4

=item *
C<variant> (case-insensitive)

=item *
One or more whitespace characters

=item *
C<of> (case-insensitive)

=item *
One or more whitespace characters

=back

The actual reference has three possible formats.  All of these formats
make reference to a I<C-Char>.  A C-Char is defined as all codepoints in
Unicode General Category Lo (Letter-Other), as well as the CJK Symbols
and Punctuation block [U+3000, U+303F] and the Geometric Shapes block
[U+25A0, U+25FF].

The first reference format is as follows:

=over 4

=item *
Sequence of zero or more non-whitespace characters

=item *
Any C-Char codepoint

=item *
Sequence of zero or more non-whitespace characters

=item *
Sequence of zero or more whitespace characters

=item *
Left square bracket C<[>

=item *
Sequence of zero or more characters excluding square brackets C<[]>

=item *
Right square bracket C<]>

=back

For this reference format, the opening sequence of non-whitespace (which
includes at least one C-Char) is a Han-character rendering, and
everything between the square brackets is a Pinyin rendering of that
Han-character reference.

The second reference format is as follows:

=over 4

=item *
Sequence of zero or more non-whitespace characters

=item *
Any C-Char codepoint

=item *
Sequence of zero or more non-whitespace characters

=back

The third reference format is as follows:

=over 4

=item *
Sequence of zero or more non-whitespace characters

=item *
Any C-Char codepoint

=item *
Sequence of zero or more non-whitespace characters

=item *
Vertical bar C<|>

=item *
Sequence of zero or more non-whitespace characters

=item *
Any C-Char codepoint

=item *
Sequence of zero or more non-whitespace characters

=back

The second and third reference formats include only Han character
renderings without any Pinyin.  The second format includes a single
sequence of non-whitespace characters with at least one C-Char that
specifies the Han character rendering.  The third format includes two
sequences of non-whitespace characters separated by a vertical bar,
specifying the traditional and simplified renderings.

=cut

# ==================
# Program entrypoint
# ==================

# Switch output to UTF-8
#
binmode(STDERR, ":encoding(UTF-8)") or
  die "Failed to set UTF-8 output, stopped";
binmode(STDOUT, ":encoding(UTF-8)") or
  die "Failed to set UTF-8 output, stopped";

# Check that no arguments
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Open the parser
#
my $dict = Dict::Parse->load($config_dictpath);

# Go through all records
#
while ($dict->advance) {
  # Check whether any variant references are detected
  my $has_variant_ref = 0;
  if (scalar(Dict::Util->variants($dict->senses)) > 0) {
    $has_variant_ref = 1;
  }
  
  # Look if this record has any glosses including "variant of" anywhere
  # within them, and also verify that no gloss has "variant of" in it
  # more than once
  my $has_variant = 0;
  for my $sense ($dict->senses) {
    for my $gloss (@$sense) {
      (not ($gloss =~ /variant\s+of.*variant\s+of/i)) or
        die "Multiple variants in single gloss, stopped";
      if ($gloss =~ /variant\s+of/i) {
        $has_variant = 1;
        last;
      }
    }
    (not $has_variant) or last;
  }
  
  # Should never have variant ref but not variant
  (not ($has_variant_ref and (not $has_variant))) or die "Unexpected";
  
  # If we have a variant but not a variant ref, then report this line
  # number
  if ($has_variant and (not $has_variant_ref)) {
    printf "%d\n", $dict->line_number;
  }
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
