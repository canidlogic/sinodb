# NAME

createdb.pl - Create a new Sino database with the appropriate structure.

# SYNOPSIS

    ./createdb.pl

# DESCRIPTION

This script is used to create a new, empty database for Sino, with the
appropriate structure but no records.

See `config.md` in the `doc` directory for configuration you must do
before using this script.

The database must not already exist or a fatal error occurs.

The SQL string embedded in this script contains the complete database
structure.  The following subsections describe the function of each
table within the database.

## word table

The word table is the main list of words.  However, since nearly all of
the word fields can have multiple values, the word table only stores
fields that have a single value.  Currently, this is only `wordlevel`,
which has one of the following values:

     wordlevel |       Meaning
    ===========+======================
         1     | TOCFL Novice 1
         2     | TOCFL Novice 2
         3     | TOCFL Level 1
         4     | TOCFL Level 2
         5     | TOCFL Level 3
         6     | TOCFL Level 4
         7     | TOCFL Level 5

When different TOCFL source words are merged together in this table, the
merged word has the minimum wordlevel of the words being merged.

## han table

The han table stores the Chinese characters for each word.  Each word
may have multiple Han readings.  The `wordid` is a foreign key into the
`word` table.  `hanord` determines the ordering if there are multiple
versions for the same word.  `hantrad` stores the traditional
characters.

The `hantrad` field must be unique, so that two different words are
_not_ allowed to have the same Han character rendering.  This does
happen sometimes in the TOCFL dataset, in which case words are merged
together.

When different TOCFL source words are merged together in this table, the
merged word has all unique Han renderings across the merged words.

## pny table

The pny table stores the Pinyin readings for each Han reading in the
`han` table.  These Pinyin readings are taken only from the TOCFL data
files, so they should all be for Taiwan Mandarin.  Each Han reading may
have multiple Pinyin readings.  The `hanid` is a foreign key into the
`han` table.  `pnyord` determines the ordering if there are multiple
Pinyin readings for the same Han reading.  `pnytext` is the actual
Pinyin.  The format used in the TOCFL data files is used in the Sino
database, with syllables written directly after on another,
Unicode diacritics used for tone marking, and everything lowercase.

However, breve diacritics in the TOCFL data files are replaced with the
proper caron diacritics, parenthetical options are not allowed,  ZWSP is
dropped when it occurs, the lowercase a variant codepoint is replaced
with ASCII a, and a couple of cases where the wrong vowel was marked
with the tonal diacritic are corrected.  See the `import_tocfl.pl`
script for further information.

When different TOCFL source words are merged together in this table, the
merged word has all unique Pinyin renderings across the merged words.

## wclass table

The wclass table defines the full set of part-of-speech designations.
The names of the word classes must be unique.  Furthermore, each name
begins with an uppercase ASCII letter followed by a sequence of zero or
more additional characters, which must each be either lowercase ASCII
letters or hyphens.  The `wclassfull` is the full name of the word
class, as opposed to `wclassname` which is an abbreviation.

## wc table

The wc table associates part-of-speech designations with words.
`wordid` is a foreign key into the `word` table.  `wcord` determines
the ordering if there are multiple part-of-speech designations for a
single word.  `wclassid` is a foreign key into the `wclass` table,
selecting the part-of-speech.  Some words do not have any word class
designation with them.

When different TOCFL source words are merged together in this table, the
merged word has all unique part-of-speech designations across the merged
words.

## mpy table

The mpy table stores the top-level definition records from CC-CEDICT
that will be associated with Han characters.  Each record in this table
corresponds to a single record in the CC-CEDICT dictionary file.  Since
there may be multiple records in CC-CEDICT for each Han reading, this
table allows for multiple definitions for each Han reading, with
`mpyord` used to order each of these definition records.

This table also stores additional data from the CC-CEDICT dictionary
that is specific to individual records.  The `mpysimp` field stores the
simplified-character Han reading.  The `mpypny` field stores the Pinyin
from CC-CEDICT.  Note that this Pinyin is in a different format than is
used in the `pny` table, and also note that mainland pronunciations are
used instead of Taiwan Mandarin.

## dfn table

The dfn table associates glosses from CC-CEDICT with definition records
in the `mpy` table.  `mpyid` is a foreign key into that table.

CC-CEDICT glosses for a particular Han reading are organized according
to two sequence orderings.  The greater sequence ordering is `dfnosen`,
the sense ordering.  The lesser sequence ordering is `dfnogls`, the
gloss ordering.  Finally, `dfntext` gives the actual gloss text.

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
