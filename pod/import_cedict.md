# NAME

import\_cedict.pl - Import data from CC-CEDICT into the Sino database.

# SYNOPSIS

    ./import_cedict.pl

# DESCRIPTION

This script is used to fill a Sino database with information derived
from the CC-CEDICT data file.  

This script should be your fourth step after using `createdb.pl` to
create an empty Sino database, `import_tocfl.pl` to add the TOCFL
data, and `import_coct.pl` to add the COCT data.  You must have at
least one word defined already in the database or this script will fail.

This iterates through every record in CC-CEDICT in two passes.  In the
first pass, for each record, check whether its traditional character
rendering matches something in the `han` table.  If it does, then the
record data will be imported and linked properly within the Sino
database.

In the second pass, check for the situation of words that didn't get any
entry in the `mpy` table after the first pass because their Han
rendering is recorded in the CC-CEDICT data file as a simplified
rendering rather than a traditional one.  Go through the CC-CEDICT
again, but this time check whether the CC-CEDICT's record _simplified_
rendering matches something in the `han` table _and_ that whatever it
matches either belongs to a word for which there are no `dfn` records
for any of its Han renderings yet or the word is recorded in the
simplified words hash.  Add glosses of such records to the database, and
also add the word to the simplified words hash so that other simplified
records matching it can be picked up.

At the end of the script, the IDs of all of the simplified words that
were used in the second pass are reported.

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
