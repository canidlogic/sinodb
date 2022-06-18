# NAME

ugloss.pl - Report all glosses that contain non-citation Unicode beyond
ASCII range or square brackets, and the words they belong to.

# SYNOPSIS

    ./ugloss.pl
    ./ugloss.pl -wordid

# DESCRIPTION

This script scans through all glosses in the `dfn` table.  For each
gloss, all codepoints are examined that are not part of any citation.
If any of these codepoints are outside the range \[U+0020, U+007E\], or if
any of these codepoints are ASCII square brackets, the gloss is printed
(with citations removed) to output, along with the word ID the gloss
belongs to.

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
