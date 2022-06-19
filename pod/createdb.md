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

     wordlevel | TOCFL level | COCT level |  Special
    ===========+=============+============+============
         1     | Novice 1    |     -      |     -
         2     | Novice 2    |     1      |     -
         3     | Level 1     |     2      |     -
         4     | Level 2     |     3      |     -
         5     | Level 3     |     4      |     -
         6     | Level 4     |     5      |     -
         7     | Level 5     |     6      |     -
         8     |      -      |     7      |     -
         9     |      -      |     -      | level9.txt 

When different TOCFL source words are merged together in this table, the
merged word has the minimum `wordlevel` of the words being merged.

## han table

The han table stores the Han characters for each word.  Each word may
have multiple Han readings.  The `wordid` is a foreign key into the
`word` table.  `hanord` determines the ordering if there are multiple
versions for the same word.  `hantrad` stores the traditional
characters.

The `hantrad` field must be unique, so that two different words are
_not_ allowed to have the same Han character rendering.  This does
happen sometimes in the TOCFL dataset, in which case words are merged
together.

When different TOCFL source words are merged together, the merged word
has all the unique Han renderings across the merged words.

## pny table

The pny table stores the Pinyin readings for each Han reading in the
`han` table.  These Pinyin readings are taken only from the TOCFL data
files, so they should all be for Taiwan Mandarin.  Each Han reading may
have multiple Pinyin readings.  The `hanid` is a foreign key into the
`han` table.  `pnyord` determines the ordering if there are multiple
Pinyin readings for the same Han reading.  `pnytext` is the actual
Pinyin.  The Pinyin is normalized into standard form (see `pinyin.md`
for details of the standard format).

When different TOCFL source words are merged together, the merged word
has all the unique Pinyin renderings of all the unique Han readings
across the merged words.

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

## ref table

The ref table stores CC-CEDICT reference entities.  Each reference
entity must have a traditional Han reading and a simplified Han reading.
(If traditional and simplified are the same, then both fields should
have the same value.)  The traditional field is `reftrad` and the
simplified field is `refsimp`.

A reference entity may optionally have a Pinyin reading.  If present,
the Pinyin reading is stored in `refpny` and must be in normalized form
(see `pinyin.md`).  If not present, the field may be NULL.  Note that
reference entity Pinyin generally uses mainland pronunications rather
than Taiwanese.

## mpy table

The mpy table stores the top-level definition records from CC-CEDICT
that will be associated with Han characters.  Each record in this table
corresponds to a single record in the CC-CEDICT dictionary file.  Since
there may be multiple records in CC-CEDICT for each Han reading, this
table allows for multiple definitions for each Han reading, with
`mpyord` used to order each of these definition records.

This table also stores additional data from the CC-CEDICT dictionary
that is specific to individual records.  There is a foreign key into the
ref table that defines the traditional, simplified, and Pinyin readings
of this particular record as they appear in CC-CEDICT.  (NULL is used
for Pinyin when the Pinyin in CC-CEDICT fails to normalize.)  Also, the
`mpyprop` field is 1 if the original CC-CEDICT Pinyin had any uppercase
letters in it (indicating a proper name entry), else zero.

In a few cases, the TOCFL/COCT word list uses Han forms that are
considered simplified in CC-CEDICT, so in those cases the Han from the
`han` table will match with the simplified reading in the reference
entity rather than the traditional one.

## dfn table

The dfn table associates glosses from CC-CEDICT with definition records
in the `mpy` table.  `mpyid` is a foreign key into that table.

When there are multiple glosses for an `mpy` record, `dfnord` is used
to establish an ordering for them.

There is also a `dfnsen` field which indicates the sense number.
Glosses when ordered by `dfnsen` will be in the same order as for the
`dfnord` field, except that there might be multiple glosses with the
same sense number.

Example of `dfnord` and `dfnsen`:

     dfnsen | dfnord |                    dfntext
    ========+========+===============================================
        1   |    1   | complete change from the normal state (idiom)
        1   |    2   | quite uncharacteristic
        2   |    3   | entirely outside the norm
        3   |    4   | out of character

In this example, the first two glosses are both part of the same sense,
while the last two glosses are each their own sense.

`dfntext` gives the gloss text.  However, classifier glosses, alternate
pronunciation glosses, and cross-reference glosses have already been
extracted and are not present in the gloss text.  No glosses with empty
gloss text are allowed.

## cit table

The cit table annotates glosses in the dfn table with citations.
Citations reference a substring of a specific gloss and provide a parsed
representation of it.

Each record in this table has a foreign key into the dfn table, and then
`citoff` and `citlen` fields defining the codepoint starting offset
and codepoint length of the citation within the gloss.  Each record also
has a foreign key into the ref table which specifies the parsed form of
the citation.

## msm and msd tables

The msm and msd tables define measure words (also known as classifiers)
and associate them with records in the `mpy` and `dfn` tables.  The
only difference between msm and msd is that msm links to the `mpy`
table and msd links to the `dfn` table.

Both tables contain a foreign key defining what they are annotating
(`mpyid` or `dfnid`).  Both tables have an `msmord` or `msdord`
field that orders measure words when there are multiple measure word
annotations on the same entity.  Finally, both tables have a foreign key
into the `ref` table that identifies the specific classifier.

## atm table

The atm table defines atom strings that are used in pronunciation and
cross-reference glosses.  Since there is a lot of repetition in these
values, it makes sense to have an atom table.

`atmid` lets atoms be referenced by a foreign key, while `atmval` is
the actual text of the atom, which may be an empty string.  However,
`atmval` must be unique within the atom table.

## apm and apd tables

The apm and apd tables define alternate pronunications and associate
them with records in the `mpy` and `dfn` tables.  The only difference
between apm and apd is that apm links to the `mpy` table and apd links
to the `dfn` table.

Both tables contain a foreign key defining what they are annotating
(`mpyid` or `dfnid`).  Both tables have an `apmord` or `apdord`
field that orders pronunciations when there are multiple pronunciation
annotations on the same entity.  Both tables have a `apmpny` or
`apdpny` field that stores the Pinyin for the alternate pronunciation,
normalized according to `pinyin.md`.  Finally, both tables have
`ctx` and `cond` fields specifying the context and condition in which
the alternate pronunication is used.  Both of these fields are foreign
keys into the atm table.

## xrm and xrd tables

The xrm and xrd tables define cross-references and associate them with
records in the `mpy` and `dfn` tables.  The only difference between
xrm and xrd is that xrm links to the `mpy` table and xrd links to the
`dfn` table.

Both tables contain a foreign key defining what they are annotating
(`mpyid` or `dfnid`).  Both tables have an `ord` field that orders
cross-references when there are multiple cross-reference annotations on
the same entity.  Both tables have a foreign key into the ref table
identifying the cross-reference.  Finally, both tables have `desc`
`type` and `suf` fields specifying the cross-reference descriptor,
the cross-reference type, and the cross-reference suffix.  Each of these
three final fields are foreign keys into the atm table.

## tok and tkm tables

The tok and tkm tables are used for searching through the glosses for
token keywords.

The tok table defines unique search tokens.  Search tokens are sequences
of one or more ASCII lowercase letters, with apostrophe allowed at most
once so long as it is neither the first nor last character.  Tokens are
case insensitive and also diacritic marks on Latin letters should be
removed.

The tkm table defines the token content of each gloss.  There is also a
`pos` field, which indicates the position of the token within the
gloss.  A position of zero means the token is the first token in the
gloss, a position of one means the second token in the gloss, and so
forth.

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
