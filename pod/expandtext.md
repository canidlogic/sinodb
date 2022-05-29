# NAME

expandtext.pl - Expanded an exported COCT text file into records.

# SYNOPSIS

    ./expandtext.pl < coct.txt > coct.csv

# DESCRIPTION

This script will read UTF-8 text from standard input, line by line.  Any
line that does not have at least 9 ASCII commas on it will be ignored.
Each line with at least 9 ASCII commas will be split up into a sequence
of comma-separated words.  Each of these words will be output on a
single line as two fields separated by a comma, the first field being a
decimal integer identifying the data set and the second field being the
actual word.  The first line with at least 9 ASCII commas is data set 1,
the second line with at least 9 ASCII commas is data set 2, and so
forth.

This script is intended as a conversion aid for the COCT data when you
are using the Word file source.  In this case, convert the Word file to
a UTF-8 plain-text file using LibreOffice Writer or the like.  Then, run
that plain-text file through this script to convert it to CSV.

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
