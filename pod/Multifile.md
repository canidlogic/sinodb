# NAME

Sino::Multifile - Iterate through the lines in a sequence of files.

# SYNOPSIS

    use Sino::Multifile;
    
    # Open the data files
    my $mr = Sino::Multifile->load($file_arrayref);
    
    # (Re)start an iteration through the files
    $mr->rewind;
    
    # Rewind but start at a given file index
    $mr->rewindTo(1);
    
    # Get current file index
    my $findex = $mr->file_index;
    
    # Get current line number, or 0 if Beginning Of Stream (BOS)
    my $lnum = $mr->line_number;
    
    # Read each file line
    while ($mr->advance) {
      # Get line just read
      my $ltext = $mr->text;
      ...
    }

# DESCRIPTION

Module that opens and allows for iteration through all the lines in a
sequence of files.

See the synopsis for parsing operation.  This module only stores a
single line in memory at a time, so it should handle large data files.

However, the parser object will store open file handles to each of the
files, so don't attempt to open large numbers of files with this module
or you may run out of file handles.

# CONSTRUCTOR

- **load(file\_paths)**

    Construct a new file sequence reader object.  `file_paths` is an array
    reference to the paths of the files you want to read through, in the
    order they should be read.

    Read-only file handles to the data files are kept open while the object
    is constructed.  Do not try to read through large numbers of files with
    this module or you may run out of file handles.  Undefined behavior
    occurs if the data files change while this reader object is opened on
    them.  The destructor for this object will close the file handles
    automatically.

    The handles are opened in UTF-8 mode with CR+LF translation mode active.
    Any UTF-8 Byte Order Mark (BOM) at the start of the files are skipped.

    The provided array must have at least one file path.

    This constructor does not actually read anything from the files yet.

# DESTRUCTOR

The destructor for the parser object closes the file handles.

# INSTANCE METHODS

- **rewind()**

    Rewind the data files back to the beginning and change the state of this
    reader to Beginning Of Stream (BOS).  This is also the initial state of
    the reader object after construction.  No record is currently loaded
    after calling this function.

    This rewinds all the way back to the start of the first file, regardless
    of which file you are currently reading.

- **rewindTo(index)**

    Similar to a `rewind()` operation, except the reader object will be
    positioned so that the current file index is equal to `index` and the
    first line read will be the first line of file `index`.  No record is
    currently loaded after calling this function.

    `index` must be at least zero and less than the number of file paths
    that was passed to the constructor.

- **file\_index()**

    Get the index of the file we are currently reading through, where zero
    is the first file.  This property is always available, even if a record
    is not currently loaded.  The line\_number() is located within the file
    indicated by this level.

- **line\_number()**

    Get the current line number in the current file.  After construction and
    also immediately following a rewind, this function will return zero. 
    After an advance operation that returns true, this will return the line
    number of the record that was just read (where the first line is 1).
    After an advance operation that returns false, the return value of this
    function is zero.

    The line number is the line number within the current file, as
    determined by file\_index().

- **advance()**

    Read the next line from the data files.

    Each call to this function loads a new line.  Note that when the reader
    object is initially constructed, and also immediately following a rewind
    operation, no record is loaded, so you must call this function _before_
    reading the first line.

    The return value is 1 if a new record was loaded, 0 if we have reached
    End Of Stream (EOS) in the last file.  Once EOS is reached, subsequent
    calls to this function will return EOS until a rewind operation is
    performed.

    This function will read through all the files in the order given in the
    constructor, without any interruption between the files.  The function
    file\_index() can be used to check which file has just been read from
    after a successful call to advance().

- **text()**

    Get the line that was just read.

    This may only be used after a successful call to the advance function.
    A fatal error occurs if this function is called in Beginning Of Stream
    (BOS) or End Of Stream (EOS) state.

    The returned string may include Unicode codepoints.  Any UTF-8 Byte
    Order Mark (BOM) will already be dropped, and any line break characters
    at the end of the line will already be dropped also.

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
