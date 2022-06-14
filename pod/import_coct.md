# NAME

import\_coct.pl - Import data from COCT into the Sino database.

# SYNOPSIS

    ./import_coct.pl

# DESCRIPTION

This script is used to supplement a Sino database with words from the
COCT vocabulary data file.  This script should be run after using
`import_tocfl.pl` to import all the TOCFL words.

See `config.md` in the `doc` directory for configuration you must do
before using this script.

There must be at least one word already defined in the database.  This
script will parse through the COCT vocabulary list.  Only records where
_all_ headwords are not already in the database will be added; if any
of the variant forms are already in the Sino database, the whole COCT
record is skipped.  COCT levels are increased by one before adding into
the database, since COCT levels are one greater than TOCFL levels.

Since `Sino::COCT` is used as the parser, the blocklist will be
transparently applied.

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
