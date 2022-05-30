# NAME

nogloss.pl - Report the word IDs of all words that don't have any
glosses for any of their Han renderings.

# SYNOPSIS

    ./nogloss.pl
    ./nogloss.pl -min 4
    ./nogloss.pl -max 2
    ./nogloss.pl -multi
    ./nogloss.pl -level 1

# DESCRIPTION

This script goes through all words in the Sino database.  For each word,
it checks whether the word has at least one Han rendering that has an
entry in the `mpy` major definition table which has at least one gloss
in the `dfn` table.  The IDs of any words that don't have a single
gloss are reported.

The `-multi` option, if provided, specifies that only records that have
at least two Han renderings should be checked.

The `-level` option, if specified, specifies that only records that
have a word level matching the given level are considered.

The `-min` option, if provided, specifies the minimum number of
characters at least one of the Han renderings must have for the record
to be checked.  If not provided, a default of zero is assumed.

The `-max` option, if provided, specifies the maximum number of
characters _all_ Han renderings must have for the record to be checked.
If not provided, an undefined default is left that indicates there is no
maximum.

You can mix these options any way you wish.

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
