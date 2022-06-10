# NAME

Sino::TOCFL - Parse through the TOCFL data files.

# SYNOPSIS

    use Sino::TOCFL;
    use SinoConfig;
    
    # Open the data files
    my $tvl = Sino::TOCFL->load($config_tocfl, $config_datasets);
    
    # (Re)start an iteration through the dataset
    $tvl->rewind;
    
    # Get current vocabulary level
    my $level = $tvl->word_level;
    
    # Get current line number, or 0 if Beginning Of File (BOF)
    my $lnum = $tvl->line_number;
    
    # Read each TOCFL record
    while ($tvl->advance) {
      # Get record fields
      my @han_readings = $tvl->han_readings;
      my @pinyins      = $tvl->pinyin_readings;
      my @word_classes = $tvl->word_classes;
      my $word_level   = $tvl->word_level;
      
      ...
    }

# DESCRIPTION

Module that opens and allows for parsed iteration through the TOCFL data
files.  It is recommended that you get the path to the data files from
the <SinoConfig> module, as shown in the synopsis.

See the synopsis for parsing operation.  This module only stores a
single entry in memory at a time, so it should have no trouble handling
large data files.

See `config.md` in the `doc` directory for configuration you must do
before using this module.

# CONSTRUCTOR

- **load(data\_paths, dataset\_path)**

    Construct a new TOCFL parser object.  `data_paths` is an array
    reference to the paths to seven CSV files storing the TOCFL data, sorted
    in increasing level of word difficulty.  Normally, you get this array
    reference from the `SinoConfig` module, as shown in the synopsis.

    `dataset_path` is the path to the directory containing Sino
    supplemental datasets.  This is passed through and used to get an
    instance of `Sino::Blocklist`.  See that module for further details.
    Normally, you get this path from the `SinoConfig` module, as shown in
    the synopsis.

    Read-only file handles to the data files are kept open while the object
    is constructed.  Undefined behavior occurs if the data files change 
    while a parser object is opened.  The destructor of the internal file
    reader object will close the file handles automatically.

    This constructor does not actually read anything from the files yet.

# INSTANCE METHODS

- **rewind()**

    Rewind the data files back to the beginning of the whole TOCFL dataset
    and change the state of this parser to Beginning Of Stream (BOS).  This
    is also the initial state of the parser object after construction.  No
    record is currently loaded after calling this function.

    This rewinds all the way back to the start of the first vocabulary
    level, regardless of which vocabulary level you are currently on.

- **word\_level()**

    Get the TOCFL word level that we are currently examining.  This property
    is always available, even if a record is not currently loaded.  The
    line\_number() is located within the file indicated by this level.

    The TOCFL word levels are 1-7, where 1 and 2 are Novice1 and Novice2,
    and 3-7 are Level1-Level5.

- **line\_number()**

    Get the current line number in the current vocabulary file.  After
    construction and also immediately following a rewind, this function will
    return zero.  After an advance operation that returns true, this will
    return the line number of the record that was just read (where the first
    line is 1).  After an advance operation that returns false, this will
    return zero.

    The line number is the line number within the current vocabulary level
    file, as returned by word\_level().

- **advance()**

    Read and parse a record from the data files.

    Each call to this function loads a new record.  Note that when the
    parser object is initially constructed, and also immediately following
    a rewind operation, no record is loaded, so you must call this function
    _before_ reading the first record in the dataset.

    The return value is 1 if a new record was loaded, 0 if we have reached
    End Of Stream (EOS) in the last vocabulary level.  Once EOS is reached,
    subsequent calls to this function will return EOS until a rewind
    operation is performed.

    This function will read through the vocabulary levels from easiest to
    most difficult, without any interruption between the levels.  The
    function word\_level() can be used to check which level has just been
    read after a successful call to advance().

    Fatal errors occur if this function encounters a TOCFL record line that
    it can't successfully parse.

    The blocklist is consulted, and any TOCFL records for which _all_
    headwords are on the blocklist will be silently skipped over by this
    function.

- **han\_readings()**

    Return all the headwords for this record as an array in list context.

    This may only be used after a successful call to the advance function.
    A fatal error occurs if this function is called in Beginning Of Stream
    (BOS) or End Of Stream (EOS) state.

- **pinyin\_readings()**

    Return all the Pinyin readings for this record as an array in list
    context.

    Pinyin readings returned by this function have already been corrected
    and normalized to standard Pinyin with the `tocfl_pinyin` function of
    `Sino::Util`.

    This may only be used after a successful call to the advance function.
    A fatal error occurs if this function is called in Beginning Of Stream
    (BOS) or End Of Stream (EOS) state.

- **word\_classes()**

    Return all the word classes for this record as an array in list context.

    This may only be used after a successful call to the advance function.
    A fatal error occurs if this function is called in Beginning Of Stream
    (BOS) or End Of Stream (EOS) state.

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
