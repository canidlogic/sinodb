# NAME

charscan.pl - Scan all the different characters besides ASCII controls,
whitespace, and ideographs and generate a report.

# SYNOPSIS

    ./charscan.pl file1.txt file2.txt file3.txt ...

# DESCRIPTION

Pass a sequence of zero or more file paths to this script.  Each file
will be scanned separately, but the final results are from across all
the input files.  All codepoints used in the files will be reported,
except for the following:

- `CR` U+000D Carriage Return
- `LF` U+000A Line Feed
- `SP` U+0020 Space (regular ASCII)
- Unicode General Category Lo (`Other_Letter`)

(The `Lo` class is not reported because it contains a potentially huge
number of ideographs.)

**Exception:** Characters in Bopomofo blocks _are_ reported.

Each input file must be in UTF-8.  Any leading UTF-8 Byte Order Mark
(BOM) is dropped.

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
