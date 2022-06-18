# NAME

Sino::Op - Sino database operations module.

# SYNOPSIS

    use Sino::Op qw(
          string_to_db
          db_to_string
          wordid_new
          enter_han
          enter_wordclass
          enter_pinyin
          enter_ref
          enter_atom
          words_xml);
    
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
    
    # Enter a reference in the ref table if it doesn't already exist, and
    # in all cases return the refid for the reference
    my $ref_id = enter_ref($dbc, $trad, $simp, $pinyin);
    
    # Enter an atom if it doesn't already exist, and in all cases return
    # the atmid for the atom
    my $atom_id = enter_atom($dbc, 'example');
    
    # Get an XML representation for a given sequence of words
    my $xml = words_xml($dbc, [5, 24, 351]);

# DESCRIPTION

Provides various database operation functions.  See the documentation of
the individual functions for further information.

## XML description format

This subsection documents the XML format used in the `words_xml`
function.

The overall structure of the document is summarized as follows:

    <?xml version="1.0" encoding="UTF-8"?>
    <words>
      <word recid="5" level="2" wcs="..., ..., ...">
        <r han="..." pnys="..., ..., ...">
          <m trad="..." simp="..." pny="..." type="proper">
            <n type="msw" trad="..." simp="..." pny="..."/>
            <n type="alt" ctx="..." pny="..." cond="..."/>
            <n type="ref"
                desc="..."
                mode="..."
                trad="..." simp="..." pny="..."
                suff="..."/>
            ...
            <d sense="1" gloss="...">
              <c off="5" len="7" trad="..." simp="..." pny="..."/>
              ...
              <n type="msw" trad="..." simp="..." pny="..."/>
              ...
            </d>
            ...
          </m>
          ...
        </r>
        ...
      </word>
      
      <word recid="24" level="5" wclass="..., ..., ...">
        ...
      </word>
      
      ...
    </words>

An _attribute list_ is an attribute value containing a sequence of one
or more strings, where the separators between each string is a comma and
a space.  These lists are represented by `..., ..., ...` in the example
above.

For any element shown in the example above where there are three
attributes `trad` `simp` and `pny` the following rules apply.
`trad` and `simp` are required, giving the traditional reading and
the simplified reading.  If both traditional and simplified readings are
the same, both attributes are still required and both should have the
same value.  The `pny` attribute is optional.  If present, it must
contain a normalized Pinyin pronunciation.

The top-level entity is a container element `words` that contains
individual `word` elements, which are each completely separate from
each other.  Allowing multiple word elements allows for multiple word
queries in one transaction, which is more efficient.

Each `word` element is required to have a `recid` attribute and a
`level` attribute which identify the unique word ID within the Sino
database and the vocabulary level 1-9 associated with the word.
Optionally, word elements may have a `wcs` element, which is a list
attribute of one or more word class names that apply to this word.  The
word classes, if present, come from the TOCFL data.

Word elements are also containers for one or more `r` elements, which
define the individual readings of the word.  Each reading element must
have a `han` attribute, which defines one specific Han reading of the
word.  Each reading element may optionally have a `pnys` attribute,
which is an attribute list of one or more normalized Pinyin renderings
of this reading element.  The `han` attribute is either from TOCFL or
COCT, except for level 9, where it is from CC-CEDICT.  The `pnys`
attribute if present is from TOCFL.

Each reading element is also a container for zero or more `m` elements,
which define the major meanings of the reading.  Each `m` element has
required `trad` and `simp` attributes, as well as an optional `pny`
attribute.  There is also an optional `type` attribute which may have
the value `common` or `proper`, indicating meanings that CC-CEDICT
associates as not proper names or proper names, respectively; if not
specified, `common` is assumed.  The `trad` and `simp` are according
to CC-CEDICT.  The `han` of the parent `r` element does _not_
necessarily match `trad`.  Sometimes it might match `simp` instead, or
it could even match neither.  `pny` is according to CC-CEDICT, so it
favors mainland pronunications.

Within each major meaning element is a sequence of zero or more
definition elements `d`.  Each definition element must have a `sense`
attribute that gives a sense number, as well as a `gloss` attribute
that stores the actual gloss.

Both `m` and `d` elements may contain sequences of zero or more `n`
elements, which represent annotations on their parent element.
Annotation elements must have a `type` attribute with a value either
`msw` `alt` or `ref` declaring the annotation type as either a
measure word (classifier), alternate pronunciation, or cross-reference.
There may be multiple annotations of each type.

Measure-word annotations have the required `trad` and `simp` 
attributes and the optional `pny` attribute to associate a measure word
either with the whole meaning element or with a specific gloss.

Alternate-pronunciation annotations have optional `ctx` and `cond`
attributes defining the context in which the alternate pronunciation is
used and any special conditions or meanings attached to the alternate
pronunication.  All such annotations of course also have a required
`pny` attribute defining the normalized Pinyin of the alternate
pronunication.  Since these annotations comes from CC-CEDICT, Taiwanese
pronunications are considered an "alternate" pronunication.  These
annotations associate the alternate pronunication either with the whole
meaning element or with a specific gloss.

Cross-reference annotations have optional `mode` `desc` and `suff`
attributes defining a cross-reference mode, a descriptor modifier of
that mode, and a suffix with more information about the cross-reference.
Cross-reference annotations must have `trad` and `simp` attributes and
optionally a `pny` attribute.  These annotations associate the
cross-reference either with the whole meaning element or with a specific
gloss.

Definition elements may also contain zero or more `c` elements, which
represent citations within the gloss.  Each citation must have `off`
and `len` attributes that define the codepoint offset and codepoint
length of the citation within the parent element's `gloss` attribute,
as well as require `trad` and `simp` attributes and an optional `pny`
field.  Citations will not overlap within the gloss, and each must
select a valid range of characters within the gloss.

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

- **enter\_ref(dbc, trad, simp, pinyin)**

    Given a `Sino::DB` database connection, a traditional Han reading, a
    simplified Han reading, and optionally a Pinyin reading, enter this
    reference in the ref table if not already present, and in all cases
    return a `refid` corresponding to the given reference. 

    `trad` `simp` and `pinyin` should be Unicode strings, not a binary
    strings.  `pinyin` may also be `undef` for cases where a Pinyin 
    reading isn't part of the reference, or where a main entry has Pinyin
    that doesn't normalize.  If traditional and simplified readings are the
    same, pass the same string for both parameters.  Traditional and
    simplified readings may only include characters from the core CJK
    Unicode block.  The given `pinyin` must pass `pinyin_split` in
    `Sino::Util` to verify that it is normalized (unless it is `undef`).

    A r/w work block will start in this function, so don't call this
    function within a read-only block.

- **enter\_atom(dbc, str)**

    Given a `Sino::DB` database connection and a string, enter the string
    in the atom table if not already present and in all cases return a
    `atmid` corresponding to the appropriate atom record.

    `str` should be a Unicode string, not a binary string.  It may contain
    any Unicode codepoints except for ASCII control codes and surrogates.
    (Supplemental codepoints are OK.)  An empty string _is_ an acceptable
    atom string.

    A r/w work block will start in this function, so don't call this
    function within a read-only block.

- **words\_xml(dbc, ids)**

    Given a `Sino::DB` database connection and a reference to an array
    storing one or more word IDs, return a structured XML result containing
    all the information about those words from the database.  See the
    documentation at the top of this module for the specific XML format.

    The returned XML text is a Unicode string that may include Unicode
    codepoints.  If you need it in a binary string context, you should use
    UTF-8 encoding, as that is what is declared in the XML header.

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
