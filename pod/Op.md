# NAME

Sino::Op - Sino database operations module.

# SYNOPSIS

    use Sino::Op qw(
          string_to_db
          db_to_string
          wordid_new
          enter_han
          enter_wordclass
          enter_pinyin);
    
    # Convert Unicode string to binary format needed for SQLite
    my $database_string = string_to_db($unicode_string);
    
    # Convert binary format for SQLite into Unicode string
    my $unicode_string = db_to_string($database_string);
    
    # Other operations require a database connection
    use Sino::DB;
    use SinoConfig;
    my $dbc = Sino::DB->connect($config_dbpath, 0);
    
    # Get a new word ID (should be within a work block!)
    my $dbh = $dbc->beginWork('rw');
    my $word_id = wordid_new($dbc);
    ...
    $dbc->finishWork;
    
    # Enter a Han reading of a specific word ID and get the hanid
    my $han_id = enter_han($dbc, $word_id, $han_reading);
    
    # Enter a word class of a specific word ID
    enter_wordclass($dbc, $word_id, 'Adv');
    
    # Enter a Pinyin reading of a specific Han reading
    enter_pinyin($dbc, $han_id, $pinyin);

# DESCRIPTION

Provides various database operation functions.  See the documentation of
the individual functions for further information.

# FUNCTIONS

- **string\_to\_db($str)**

    Get a binary UTF-8 string copy of a given Unicode string.

    Since `Sino::DB` sets SQLite to operate in binary string mode, you must
    encode any Unicode string into a binary string with this function before
    you can pass it through to SQLite.

    If you know the string only contains US-ASCII, this function is
    unnecessary.

- **db\_to\_string($str)**

    Get a Unicode string copy of a given binary UTF-8 string.

    Since `Sino::DB` sets SQLite to operate in binary string mode, you must
    decode any binary UTF-8 string received from SQLite with this function
    before you can use it as a Unicode string in Perl.

    If you know the string only contains US-ASCII, this function is
    unnecessary.

- **wordid\_new(dbc)**

    Given a `Sino::DB` database connection, get a new word ID to use.  If
    no words are defined yet, the new word ID will be 1.  Otherwise, it will
    be one greater than the maximum word ID currently in use.

    **Caution:** A race will occur between the time you get the new ID and
    the time you attempt to use the new ID, unless you call this function in
    the same work block that defines the new word.

- **enter\_han(dbc, wordid, hantrad)**

    Given a `Sino::DB` database connection, a word ID, and a Han
    traditional character rendering, add it as a Han reading of the given
    word ID unless it is already present in the han table.  In all cases,
    return a `hanid` corresponding to this reading in the han table.

    Fatal errors occur if the given word ID is not in the word table, or if
    the Han traditional character rendering is already used for a different
    word ID.

    `hantrad` should be a Unicode string, not a binary string.  A r/w work
    block will start in this function, so don't call this function within a
    read-only block.

- **enter\_wordclass(dbc, wordid, wclassname)**

    Given a `Sino::DB` database connection, a word ID, and the name of a
    word class, add that word class to the given word ID unless it is
    already present in the wc table.

    `wclassname` is the ASCII name of the word class.  This must be in the
    wclass table already or a fatal error occurs.  Also, the given word ID
    must already be in the word table or a fatal error occurs.

    A r/w work block will start in this function, so don't call this
    function within a read-only block.
    \#
    \# This function does not check that the given wordid actually exists in
    \# the word table, and it does not check that wclassid actually is a
    \# valid foreign key.

- **enter\_pinyin(dbc, hanid, pny)**

    Given a `Sino::DB` database connection, a Han ID, and a Pinyin reading,
    add it as a Pinyin reading of the given Han ID unless it is already
    present in the pny table.

    `pny` should be a Unicode string, not a binary string.  It must pass
    the `pinyin_split()` function in `Sino::Util` to check for validity or
    a fatal error occurs.  The given Han ID must exist in the han table or a
    fatal error occurs.  A r/w work block will start in this function, so
    don't call this function within a read-only block.

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
