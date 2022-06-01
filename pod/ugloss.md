# NAME

ugloss.pl - Report all glosses that contain Unicode beyond ASCII range
or square brackets, and the words they belong to.

# SYNOPSIS

    ./ugloss.pl
    ./ugloss.pl -nocl
    ./ugloss.pl -nopk
    ./ugloss.pl -noxref
    ./ugloss.pl -wordid

# DESCRIPTION

This script reads through all glosses.  Any gloss that contains any
character outside the range \[U+0020, U+007E\], and any gloss that
contains ASCII square brackets, is printed to output, along with the
word ID the gloss belongs to.

The `-nocl` option ignores any gloss that matches a classifier gloss,
as determined by the `parse_measures` function of `Sino::Util`.

The `-nopk` option uses the `extract_pronunciation` function of
`Sino::Util` on glosses before they are examined, so that alternate
pronunciations won't be included in the reported list.

The `-noxref` option uses the `extract_xref` function of `Sino::Util`
on glosses before they are examined, so that cross-references won't be
included in the reported list.

The `-wordid` causes only a list of word IDs to be reported, rather
than glosses with word IDs.

See `config.md` in the `doc` directory for configuration you must do
before using this script.

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
