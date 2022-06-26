# NAME

hanscan.pl - Report the word IDs of all words that match a given Han
query.

# SYNOPSIS

    ./hanscan.pl '4e00...?*'
    ./hanscan.pl -strict '4e00...?*'

# DESCRIPTION

This script runs a Han headword query against the Sino database.  This
is a simple front-end for the `han_query()` function of `Sino::Op`.
See the documentation of that module for further information.

The output is a list of word IDs that match the keyword query.

The query format can contain Unicode Han characters, Han characters
encoded as sequences of exactly four base-16 digits, and the wildcards
`*` and `?`.  Encoding a Han character in base-16 versus supplying the
character directly is equivalent.

Normally, matching is _loose_, meaning that simplified and traditional
variants of the same character are equivalent.  If you want strict
matching where characters only match themselves, include the `-strict`
option.

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
