# NAME

xrefwords.pl - Generate a list of extra words that should be added to
the database so that all cross-references can resolve.

# SYNOPSIS

    ./xrefwords.pl

# DESCRIPTION

The script defines four word hashes:  the _done hash_, the _extra
hash_, the _next hash_, and the _current hash_.  Each hash maps
traditional Han renderings to an integer value of one, such that they
behave like sets of Han readings.

At the start of the script, all traditional Han readings found in the
`han` table and all traditional Han readings found in the `mpy` table
are added to the current hash, and the other three hashes are left
empty.

The script then continues making passes through CC-CEDICT until the
current hash is empty.

In each pass through CC-CEDICT, the script only examines glosses that
have a traditional Han reading that is in the current hash.  The
`extract_xref` is used on each of these glosses to check whether there
are any cross-references.  If there are, then the traditional Han
rendering(s) of each cross-reference is checked whether it is in done
hash or the current hash.  Any traditional Han renderings that are not
in either of those hases are added to the extra hash and the next hash.
At the end of the pass, all words in the current hash are moved to the
done hash, the next hash becomes the new current hash, and the next hash
is then replaced with an empty hash.

At the end of all the passes, the next hash and current hashes will both
be empty.  The extra hash will contain all words that should be added to
the database so that all cross-references can resolve.  Before the final
report, one last pass is made through the dictionary.  This time, all
headwords in the extra hash that have an entry in the dictionary have
their value changed to 2.  Output then only includes headwords from the
extra hash where the value is 2, printed to standard output, one per
line.  All of the reported extra words are then known to be in the
CC-CEDICT dictionary somewhere.

Progress reports regarding passes are printed to standard error.

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
