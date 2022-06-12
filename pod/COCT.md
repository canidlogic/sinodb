# NAME

Sino::COCT - Parse through the COCT data file.

# SYNOPSIS

    use Sino::COCT;
    use SinoConfig;
    
    # Open the data file
    my $cvl = Sino::COCT->load($config_coctpath, $config_datasets);
    
    # (Re)start an iteration through the dataset
    $cvl->rewind;
    
    # Get current line number, or 0 if Beginning Of File (BOF)
    my $lnum = $cvl->line_number;
    
    # Read each COCT record
    while ($cvl->advance) {
      my $word_level = $cvl->word_level;
      my @hws        = $cvl->han_readings;
      ...
    }

# DESCRIPTION

Module that opens and allows for parsed iteration through the COCT data
file.  It is recommended that you get the path to the data files from
the <SinoConfig> module, as shown in the synopsis.

See the synopsis for parsing operation.  This module only stores a
single entry in memory at a time, so it should have no trouble handling
large data files.

See `config.md` in the `doc` directory for configuration you must do
before using this module.

# CONSTRUCTOR

- **load(data\_path, dataset\_path)**

    Construct a new COCT parser object.  `data_path` is the path to the CSV
    file storing the COCT data.  Normally, you get this path from the
    `SinoConfig` module, as shown in the synopsis.

    `dataset_path` is the path to the directory containing Sino
    supplemental datasets.  This is passed through and used to get an
    instance of `Sino::Blocklist`.  See that module for further details.
    Normally, you get this path from the `SinoConfig` module, as shown in
    the synopsis.

    A read-only file handle to the COCT data file is kept open while the
    object is constructed.  Undefined behavior occurs if the data file
    changes while a parser object is opened.  The destructor of the internal
    file reader object will close the file handle automatically.

    This constructor does not actually read anything from the file yet.

# INSTANCE METHODS

- **rewind()**

    Rewind the data file back to the beginning of the COCT dataset and
    change the state of this parser to Beginning Of Stream (BOS).  This is
    also the initial state of the parser object after construction.  No
    record is currently loaded after calling this function.

- **line\_number()**

    Get the current line number in the COCT data file.  After construction
    and also immediately following a rewind, this function will return zero.
    After an advance operation that returns true, this will return the line
    number of the record that was just read (where the first line is 1). 
    After an advance operation that returns false, this will return zero.

- **advance()**

    Read and parse a record from the data file.

    Each call to this function loads a new record.  Note that when the
    parser object is initially constructed, and also immediately following
    a rewind operation, no record is loaded, so you must call this function
    _before_ reading the first record in the dataset.

    The return value is 1 if a new record was loaded, 0 if we have reached
    End Of Stream (EOS) in the data file.  Once EOS is reached, subsequent
    calls to this function will return EOS until a rewind operation is
    performed.

    Fatal errors occur if this function encounters a COCT record line that
    it can't successfully parse.

    The blocklist is consulted, and any COCT records for which _all_ 
    headwords are on the blocklist will be silently skipped over by this
    function.

- **word\_level()**

    Get the COCT word level that we are currently examining.

    **Note:** COCT level 1 corresponds to TOCFL level 2, COCT level 2
    corresponds to TOCFL level 3, and so forth.  The last COCT level is
    beyond the last TOCFL level.

    This may only be used after a successful call to the advance function.
    A fatal error occurs if this function is called in Beginning Of Stream
    (BOS) or End Of Stream (EOS) state.

- **han\_readings()**

    Return all the Han headwords for this record as an array in list
    context.

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
