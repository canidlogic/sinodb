# NAME

Sino::Dict - Parse through the CC-CEDICT data file.

# SYNOPSIS

    use Sino::Dict;
    use SinoConfig;
    
    # Open the data file
    my $dict = Sino::Dict->load($config_dictpath);
    
    # (Re)start an iteration through the dictionary
    $dict->rewind;
    
    # Get current line number, or 0 if Beginning Of File (BOF)
    my $lnum = $dict->line_number;
    
    # You can quickly start reading at a specific line like this
    $dict->seek($lnum);
    
    # Read each dictionary record (skipping blank and comments)
    while ($dict->advance) {
      # Traditional and simplified headwords, already decoded in Unicode
      my $trad = $dict->traditional;
      my $simp = $dict->simplified;
      
      # Array of Pinyin syllables, may include punctuation "syllables"
      my @pnya = $dict->pinyin;
      
      # Definition is array of sense subarrays
      for my $sense ($dict->senses) {
        # Sense subarrays contain glosses
        for my $gloss (@$sense) {
          ...
        }
      }
    }

# DESCRIPTION

Module that opens and allows for parsed iteration through the CC-CEDICT
data file.  It is recommended that you get the path to the CC-CEDICT
dictionary file from the <SinoConfig> module, as shown in the synopsis.

See the synopsis for parsing operation.  This module only stores a
single entry in memory at a time, so it should have no trouble handling
the large data file.

See `config.md` in the `doc` directory for configuration you must do
before using this module.

# CONSTRUCTOR

- **load(data\_path)**

    Construct a new dictionary parser object.  `data_path` is the path in
    the local file system to the _decompressed_ CC-CEDICT data file.
    Normally, you get this path from the `SinoConfig` module, as shown in
    the synopsis.

    An read-only file handle to the data file is kept open while the object
    is constructed.  Undefined behavior occurs if the data file changes
    while a parser object is opened.  The destructor for this object will
    close the file handle automatically.

    This constructor does not actually read anything from the file yet.

# DESTRUCTOR

The destructor for the parser object closes the file handle.

# INSTANCE METHODS

- **rewind()**

    Rewind the data file back to the beginning and change the state of this
    parser to Beginning Of File (BOF).  This is also the initial state of
    the parser object after construction.  No record is currently loaded
    after calling this function.

- **seek(n)**

    Rewind the data file back to the beginning and skip to immediately
    before a given line number, setting parser state to BOF.  Calling this
    with a value of 1 is equivalent to calling the rewind function.  No
    record is currently loaded after calling this function.

    First, this function performs a rewind operation.  Second, this function
    reads zero or more lines until either the current line number advances
    to one less than the given `n` value, or EOF is reached.  When advance
    is called, it will act as though the first line of the file were the
    given line number.

    `n` must be an integer greater than zero.  Note that if advance
    successfully reads a record, the line number of this record is _not_
    necessarily the same as `n`.  If `n` refers to a comment line or a
    blank line, advance will read the next line that is not a comment or
    blank.

    This function is _much_ faster than just advancing over records,
    because this function will not parse any of the lines it is skipping.

- **line\_number()**

    Get the current line number in the dictionary file.  After construction
    and also immediately following a rewind, this function will return zero.
    After an advance operation that returns true, this will return the line
    number of the record that was just read (where the first line is 1).
    After an advance operation that returns false, this will return the line
    number of the last line in the file.

- **advance()**

    Read and parse a record from the data file.

    Each call to this function loads a new record.  Note that when the
    parser object is initially constructed, and also immediately following
    a rewind operation, no record is loaded, so you must call this function
    _before_ reading the first record in the dictionary.

    The return value is 1 if a new record was loaded, 0 if we have reached
    End Of File (EOF).  Once EOF is reached, subsequent calls to this
    function will return EOF until a rewind operation is performed.

- **traditional()**

    Get the traditional-character rendering of the currently loaded
    dictionary record.

    This may only be used after a successful call to the advance function.
    A fatal error occurs if this function is called in Beginning Of File
    (BOF) or End Of File (EOF) state.

- **simplified()**

    Get the simplified-character rendering of the currently loaded
    dictionary record.

    This may only be used after a successful call to the advance function.
    A fatal error occurs if this function is called in Beginning Of File
    (BOF) or End Of File (EOF) state.

- **pinyin()**

    Return each of the Pinyin syllables of the currently loaded dictionary
    record.  The return is a list in list context.

    This may only be used after a successful call to the advance function.
    A fatal error occurs if this function is called in Beginning Of File
    (BOF) or End Of File (EOF) state.

- **senses()**

    Return all the definitions of the currently loaded dictionary record.
    The return is a list in list context.  The elements of this list
    represent the separate senses of the word.  Each element is an array
    reference, and these subarrays store a sequence of gloss strings
    representing glosses for the sense.

    This function makes a copy of the arrays it returns, so modifying the
    arrays will not affect the state of the parser object.

    Note that CC-CEDICT stores various other kinds of information here, such
    as variant references, Taiwan Pinyin, and more.

    This may only be used after a successful call to the advance function.
    A fatal error occurs if this function is called in Beginning Of File
    (BOF) or End Of File (EOF) state.

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
