# NAME

Sino::Dict - Parse through the CC-CEDICT data file.

# SYNOPSIS

    use Sino::Dict;
    use SinoConfig;
    
    # Open the data file
    my $dict = Sino::Dict->load($config_dictpath, $config_datasets);
    
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
      
      # Pinyin or undef if couldn't normalize
      my $pinyin = $dict->pinyin;
      
      # Check whether this record is for a proper name
      if ($dict->is_proper) {
        ...
      }
      
      # Record-level annotations
      my $rla = $dict->main_annote;
      for my $measure ($rla->{'measures'}) {
        my $trad = $measure->[0];
        my $simp = $measure->[1];
        my $pny;
        if (scalar(@$measure) >= 3) {
          $pny = $measure->[2];
        }
        ...
      }
      for my $pr ($rla->{'pronun'}) {
        my $pr_context = $pr->[0];
        for my $pny (@{$pr->[1]}) {
          ...
        }
        my $pr_condition = $pr->[2];
        ...
      }
      for my $xref ($rla->{'xref'}) {
        my $xr_description = $xref->[0];
        my $xr_type        = $xref->[1];
        for my $xrr (@{$xref->[2]}) {
          my $trad = $xrr->[0];
          my $simp = $xrr->[1];
          my $pny;
          if (scalar(@$xrr) >= 3) {
            $pny = $xrr->[2];
          }
        }
        my $xr_suffix      = $xref->[3];
      }
      
      # Entries
      for my $entry (@{$dict->entries}) {
        my $sense_number = $entry->{'sense'};
        my $gloss_text   = $entry->{'text'};
        my $cites        = $entry->{'cites'};
        for my $cite (@$cites) {
          # Within $gloss_text:
          my $starting_index = $cite->[0];
          my $cite_length    = $cite->[1];
          my $cite_trad      = $cite->[2];
          my $cite_simp      = $cite->[3];
          my $cite_pny;
          if (scalar(@$cite) >= 5) {
            $cite_pny = $cite->[4];
          }
        }
        
        # These properties same as the record-level annotation format
        my $gla_measures = $entry->{'measures'};
        my $gla_pronuns  = $entry->{'pronun'};
        my $gla_xrefs    = $entry->{'xref'};
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

- **load(data\_path, dataset\_path)**

    Construct a new dictionary parser object.  `data_path` is the path in
    the local file system to the _decompressed_ CC-CEDICT data file.
    Normally, you get this path from the `SinoConfig` module, as shown in
    the synopsis.

    `dataset_path` is the path to the directory containing Sino
    supplemental datasets.  This path must end with a separator character so
    that filenames can be directly appended to it.  This is used to get the
    path to `extradfn.txt` in that directory, which contains extra
    definitions to consider added on to the end of the main dictionary file.
    Normally, you get this path from the `SinoConfig` module, as shown in
    the synopsis.

    An read-only file handle to the data files is kept open while the object
    is constructed.  Undefined behavior occurs if the data files change
    while a parser object is opened.  The destructor for the underlying
    object managing the file handles will close the file handle
    automatically.

    This constructor does not actually read anything from the file yet.

# INSTANCE METHODS

- **rewind()**

    Rewind the data file back to the beginning and change the state of this
    parser to Beginning Of Stream (BOS).  This is also the initial state of
    the parser object after construction.  No record is currently loaded
    after calling this function.

    This rewinds back to the very beginning of the main dictionary file,
    even if you are currently in the supplement.

- **seek(n)**

    Rewind the data file back to the beginning and skip to immediately
    before a given line number, setting parser state to BOF.  Calling this
    with a value of 1 is equivalent to calling the rewind function.  No
    record is currently loaded after calling this function.

    You can use negative values to select line numbers in the supplement.
    \-1 is the first line in the supplement, -2 is the second line, and so
    forth.

    First, this function performs a rewind operation.  Second, this function
    reads zero or more lines until either the current line number advances
    to one less than the given `n` value, or EOS is reached.  When advance
    is called, it will act as though the first line of the file were the
    given line number.

    `n` must be an integer greater than zero or less than zero (if
    selecting a line in the supplement).  Note that if advance successfully
    reads a record, the line number of this record is _not_ necessarily the
    same as the line selected by `n`.  If `n` refers to a comment line or
    a blank line, advance will read the next line that is not a comment or
    blank, or may even go to EOS.

    This function is _much_ faster than just advancing over records,
    because this function will not parse any of the lines it is skipping.

- **line\_number()**

    Get the current line number in the dictionary file.  After construction
    and also immediately following a rewind, this function will return zero.
    After an advance operation that returns true, this will return the line
    number of the record that was just read (where the first line is 1).
    After an advance operation that returns false, this will return the line
    number of the last line in the file.

    In the supplement file, line numbers will be negative.  -1 is first line
    in supplement file, -2 is second line, and so forth.

- **advance()**

    Read and parse a record from the data file.

    Each call to this function loads a new record.  Note that when the
    parser object is initially constructed, and also immediately following
    a rewind operation, no record is loaded, so you must call this function
    _before_ reading the first record in the dictionary.

    The return value is 1 if a new record was loaded, 0 if we have reached
    End Of Stream (EOS).  Once EOS is reached, subsequent calls to this
    function will return EOS until a rewind operation is performed.

    This function will also seamlessly read through the supplement file
    after reading through the main dictionary file.

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

    Return the normalized Pinyin for this record, or `undef` if the Pinyin
    could not be normalized.

    This may only be used after a successful call to the advance function.
    A fatal error occurs if this function is called in Beginning Of File
    (BOF) or End Of File (EOF) state.

- **is\_proper()**

    Return 1 if this record is for a proper name, 0 otherwise.

    This may only be used after a successful call to the advance function.
    A fatal error occurs if this function is called in Beginning Of File
    (BOF) or End Of File (EOF) state.

    To determine whether a record is for a proper name, this parser checks
    whether the original Pinyin before normalization had any uppercase
    syllables, where an uppercase syllable is defined as an uppercase ASCII
    letter, followed by zero or more lowercase ASCII letters and colons,
    followed by a decimal digit 1-5.

- **main\_annote()**

    Return a reference to the main annotations hash for this record.

    This may only be used after a successful call to the advance function.
    A fatal error occurs if this function is called in Beginning Of File
    (BOF) or End Of File (EOF) state.

    The returned hash has three properties: `measures` `pronun` and
    `xref`.  Each of these are array references.  The measures array stores
    subarrays consisting of the traditional han, simplified han, and
    optionally the normalized Pinyin.  The pronunciations array stores
    subarrays consisting of the context, a subarray of normalized Pinyin
    readings, and a condition.  The cross-references array stores subarrays
    consisting of the description, type, subarray, and suffix, where the
    subarray has further xref subarrays with traditional han, simplified
    han, and optionally normalized Pinyin.

    **Note:** This is not a copy, so modifications to this hash update the
    main record state.

- **entries()**

    Return a reference to the entries array for this record.

    This may only be used after a successful call to the advance function.
    A fatal error occurs if this function is called in Beginning Of File
    (BOF) or End Of File (EOF) state.

    Entries are each hash references.  They have properties `measures`
    `pronun` and `xref` with the same format as for `main_annote()`.
    They also have a `sense` integer which gives the sense number this
    gloss belongs to, a `text` integer which stores the text of the gloss
    (without any annotations), and a `cites` array reference that stores
    the citations within `text`, in the same array format as is used by the
    `parse_cites()` function of `Sino::Util`.

    **Note:** This is not a copy, so modifications to this array update the
    main record state.

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
