# NAME

remap.pl - Generate a remap list for adding additional remap entries to
the database.

# SYNOPSIS

    ./remap.pl

# DESCRIPTION

This script finds cross-reference annotations belonging to words that do
not have any glosses for any of their meanings, which are below word
level 9, and for which the cross-reference annotation is not already a
Han entry below level 9.

A remap dataset is generated where each line is a record.  Lines begin
with a traditional Han reading from the `han` table, and then a
sequence of one or more cross-reference traditional Han readings
representing cross-referenced readings found for that entry.  Each
reading is separated by a space.

This script will also verify that none of the cross-referenced readings
are in the generated keyset of remapped traditional Han characters, and
that none of the cross-referenced readings occur more than once.

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
