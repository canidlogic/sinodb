# NAME

normhan.pl - Build the normalized Han lookup tables of the database.

# SYNOPSIS

    ./normhan.pl

# DESCRIPTION

This script is used to build the smp and spk normalized Han lookup
tables within the Sino database, which allow for Han headword queries
according to _normalized Han_.  Normalized Han is not part of the
Unicode standard, as is instead defined specifically by Sino as a way of
querying for headwords independent of whether characters are given in
simplified or traditional form.  See `createdb.pl` for a formal
definition of normalized Han.

This script should be run after you have imported all the glosses into
the `dfn` table using `import_cedict.pl`.  The `smp` table must be
empty when you start running this script.

The first step of this script is to go through the `ref` table and
build a hash mapping each codepoint to codepoints that are connected to
it, but excluding trivial connections of codepoints to themselves and
not including codepoints that lack any connections except to themselves.

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
