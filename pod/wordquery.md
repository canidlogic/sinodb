# NAME

wordquery.pl - List all information about particular words.

# SYNOPSIS

    ./wordquery.pl 526 1116 2561 4195
    ./wordquery.pl

# DESCRIPTION

This script reports all information about words with given ID numbers.
You can either pass the ID numbers directly as one or more program
arguments, or you can pass no arguments and the script will read the ID
numbers from standard input, with one word ID per line (especially
useful as a pipeline target for other scripts).

The information returned about the words is in the descriptive XML
format documented in the `Sino::Op` module.

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
