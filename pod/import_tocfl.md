# NAME

import\_tocfl.pl - Import data from TOCFL into the Sino database.

# SYNOPSIS

    ./import_tocfl.pl

# DESCRIPTION

This script is used to fill a Sino database with information derived
from TOCFL vocabulary data files.  This script should be your second
step after using `createdb.pl` to create an empty Sino database.

See `config.md` in the `doc` directory for configuration you must do
before using this script.

Note that the database has the requirement that no two words have the
same Han reading, but there are indeed cases in the TOCFL data where two
different entries have the same Han reading.  When this situation
happens, this script will merge the two entries together into a single
word.  The merger process is explained in further detail in the table
documentation for `createdb.pl`

This script will also handle cleaning up the input data and fixing some
typos (such as tonal diacritics in Pinyin being placed on the wrong
vowel, or some missing Pinyin readings for abbreviated forms).  It will
also intelligently use `han_exmap`, `pinyin_count`, and `han_count`
from `Sino::Util` to properly map Pinyin readings to Han character
readings, even though this isn't explicit in the TOCFL datasets.

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
