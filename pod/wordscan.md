# NAME

wordscan.pl - Report the word IDs of all words that match a given
keyword query.

# SYNOPSIS

    ./wordscan.pl 'husky sled-dog'

# DESCRIPTION

This script runs a keyword query against the Sino database.  This is a
simple front-end for the `keyword_query()` function of `Sino::Op`.
See the documentation of that module for further information.

Since using apostrophes in command-line arguments may be an issue, this
script will replace `!` characters in the keyword query with
apostrophes before it is processed.  This is not part of standard
keyword processing, but provided solely for this script as a workaround
for the awkwardness otherwise of using single-quoted arguments that must
include apostrophes.

The output is a list of word IDs that match the keyword query.

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
