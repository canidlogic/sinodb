# NAME

import\_cedict.pl - Import data from CC-CEDICT into the Sino database.

# SYNOPSIS

    ./import_cedict.pl

# DESCRIPTION

This script is used to fill a Sino database with information derived
from the CC-CEDICT data file.  

This script should be your third step after using `createdb.pl` to
create an empty Sino database and `import_tocfl.pl` to add the TOCFL
data.  You must have at least one word defined already in the database
or this script will fail.

This iterates through every record in CC-CEDICT.  For each record, check
whether its traditional character rendering matches something in the
`han` table.  If it does, then the record data will be imported and
linked properly within the Sino database.

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
