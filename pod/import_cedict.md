# NAME

import\_cedict.pl - Import data from CC-CEDICT into the Sino database.

# SYNOPSIS

    ./import_cedict.pl

# DESCRIPTION

This script is used to fill a Sino database with information derived
from the CC-CEDICT data file.  

You should only use this script after you've added all words with the
other import scripts.  This script will only add definitions for words
that already exist in the database.  You must have at least one word
defined already in the database or this script will fail.

This script performs four passes through the CC-CEDICT database.  Each
pass it only examines certain types of CC-CEDICT records, and each pass
it only processes records for which the headword is not already defined
in the database.  In this way, the passes are a fallback system, where
records from pass two are only imported for words that were not handled
in pass one, records from pass three are only imported for words that
were not handled in passes one and two, and records from pass four are
only imported for words that were not handled in passes one, two, and
three.  The four passes have the following characteristics:

     Pass | CC-CEDICT matching | Entry type
    ======+====================+============
       1  |    traditional     |   common
       2  |    simplified      |   common
       3  |    traditional     |   proper
       4  |    simplified      |   proper

With this scheme, CC-CEDICT records for proper names (that is, where the
original CC-CEDICT Pinyin contains at least one uppercase ASCII letter)
are not consulted for words unless all attempts to find definitions
amongst records that are not proper names have failed.  Also, if
matching against traditional Han readings in the CC-CEDICT fails,
matching against simplified Han readings will then be attempted as a
fallback, to handle cases where the TOCFL/COCT headwords use a rendering
that CC-CEDICT considers to be simplified.

Since this is a long process, regular progress reports are printed out
on standard error as the script is running.  At the end, a summary
screen is printed on standard output, indicating how many records were
added in each pass.

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
