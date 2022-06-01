#!/usr/bin/env perl
use strict;
use warnings;

# Sino imports
use Sino::DB;
use SinoConfig;

=head1 NAME

createdb.pl - Create a new Sino database with the appropriate structure.

=head1 SYNOPSIS

  ./createdb.pl

=head1 DESCRIPTION

This script is used to create a new, empty database for Sino, with the
appropriate structure but no records.

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

The database must not already exist or a fatal error occurs.

The SQL string embedded in this script contains the complete database
structure.  The following subsections describe the function of each
table within the database.

=head2 word table

The word table is the main list of words.  However, since nearly all of
the word fields can have multiple values, the word table only stores
fields that have a single value.  Currently, this is only C<wordlevel>,
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
merged word has the minimum wordlevel of the words being merged.

=head2 han table

The han table stores the Chinese characters for each word.  Each word
may have multiple Han readings.  The C<wordid> is a foreign key into the
C<word> table.  C<hanord> determines the ordering if there are multiple
versions for the same word.  C<hantrad> stores the traditional
characters.

The C<hantrad> field must be unique, so that two different words are
I<not> allowed to have the same Han character rendering.  This does
happen sometimes in the TOCFL dataset, in which case words are merged
together.

When different TOCFL source words are merged together in this table, the
merged word has all unique Han renderings across the merged words.

=head2 pny table

The pny table stores the Pinyin readings for each Han reading in the
C<han> table.  These Pinyin readings are taken only from the TOCFL data
files, so they should all be for Taiwan Mandarin.  Each Han reading may
have multiple Pinyin readings.  The C<hanid> is a foreign key into the
C<han> table.  C<pnyord> determines the ordering if there are multiple
Pinyin readings for the same Han reading.  C<pnytext> is the actual
Pinyin.  The format used in the TOCFL data files is used in the Sino
database, with syllables written directly after on another,
Unicode diacritics used for tone marking, and everything lowercase.

However, breve diacritics in the TOCFL data files are replaced with the
proper caron diacritics, parenthetical options are not allowed,  ZWSP is
dropped when it occurs, the lowercase a variant codepoint is replaced
with ASCII a, and a couple of cases where the wrong vowel was marked
with the tonal diacritic are corrected.  See the C<import_tocfl.pl>
script for further information.

When different TOCFL source words are merged together in this table, the
merged word has all unique Pinyin renderings across the merged words.

=head2 wclass table

The wclass table defines the full set of part-of-speech designations.
The names of the word classes must be unique.  Furthermore, each name
begins with an uppercase ASCII letter followed by a sequence of zero or
more additional characters, which must each be either lowercase ASCII
letters or hyphens.  The C<wclassfull> is the full name of the word
class, as opposed to C<wclassname> which is an abbreviation.

=head2 wc table

The wc table associates part-of-speech designations with words.
C<wordid> is a foreign key into the C<word> table.  C<wcord> determines
the ordering if there are multiple part-of-speech designations for a
single word.  C<wclassid> is a foreign key into the C<wclass> table,
selecting the part-of-speech.  Some words do not have any word class
designation with them.

When different TOCFL source words are merged together in this table, the
merged word has all unique part-of-speech designations across the merged
words.

=head2 mpy table

The mpy table stores the top-level definition records from CC-CEDICT
that will be associated with Han characters.  Each record in this table
corresponds to a single record in the CC-CEDICT dictionary file.  Since
there may be multiple records in CC-CEDICT for each Han reading, this
table allows for multiple definitions for each Han reading, with
C<mpyord> used to order each of these definition records.

This table also stores additional data from the CC-CEDICT dictionary
that is specific to individual records.  The C<mpytrad> and C<mpysimp>
fields store the traditional-character and simplified-character Han
readings.  The C<mpypny> field stores the Pinyin from CC-CEDICT.  Note
that this Pinyin is in a different format than is used in the C<pny>
table, and also note that mainland pronunciations are used instead of
Taiwan Mandarin.

In a few cases, the TOCFL/COCT word list uses Han forms that are
considered simplified in CC-CEDICT, so in those cases the Han from the
C<han> table will match with C<mpysimp> instead of with C<mpytrad>.

=head2 dfn table

The dfn table associates glosses from CC-CEDICT with definition records
in the C<mpy> table.  C<mpyid> is a foreign key into that table.

CC-CEDICT glosses for a particular Han reading are organized according
to two sequence orderings.  The greater sequence ordering is C<dfnosen>,
the sense ordering.  The lesser sequence ordering is C<dfnogls>, the
gloss ordering.  Finally, C<dfntext> gives the actual gloss text.

=cut

# Define a string holding the whole SQL script for creating the
# structure of the database, with semicolons used as the termination
# character for each statement and nowhere else
#
my $sql_script = q{

CREATE TABLE word (
  wordid    INTEGER PRIMARY KEY ASC,
  wordlevel INTEGER NOT NULL
);

CREATE INDEX ix_word_level
  ON word(wordlevel);

CREATE TABLE han (
  hanid   INTEGER PRIMARY KEY ASC,
  wordid  INTEGER NOT NULL
            REFERENCES word(wordid)
              ON DELETE CASCADE
              ON UPDATE CASCADE,
  hanord  INTEGER NOT NULL,
  hantrad TEXT UNIQUE NOT NULL,
  UNIQUE  (wordid, hanord)
);

CREATE UNIQUE INDEX ix_han_rec
  ON han(wordid, hanord);

CREATE INDEX ix_han_word
  ON han(wordid);

CREATE UNIQUE INDEX ix_han_trad
  ON han(hantrad);

CREATE TABLE pny (
  pnyid   INTEGER PRIMARY KEY ASC,
  hanid   INTEGER NOT NULL
            REFERENCES han(hanid)
              ON DELETE CASCADE
              ON UPDATE CASCADE,
  pnyord  INTEGER NOT NULL,
  pnytext TEXT NOT NULL,
  UNIQUE  (hanid, pnyord)
);

CREATE UNIQUE INDEX ix_pny_rec
  ON pny(hanid, pnyord);

CREATE INDEX ix_pny_han
  ON pny(hanid);

CREATE INDEX ix_pny_text
  ON pny(pnytext);

CREATE TABLE wclass (
  wclassid   INTEGER PRIMARY KEY ASC,
  wclassname TEXT UNIQUE NOT NULL,
  wclassfull TEXT NOT NULL
);

CREATE UNIQUE INDEX ix_wclass_name
  ON wclass(wclassname);

CREATE TABLE wc (
  wcid      INTEGER PRIMARY KEY ASC,
  wordid    INTEGER NOT NULL
              REFERENCES word(wordid)
                ON DELETE CASCADE
                ON UPDATE CASCADE,
  wcord     INTEGER NOT NULL,
  wclassid  INTEGER NOT NULL
              REFERENCES wclass(wclassid)
                ON DELETE RESTRICT
                ON UPDATE RESTRICT,
  UNIQUE    (wordid, wcord)
);

CREATE UNIQUE INDEX ix_wc_rec
  ON wc(wordid, wcord);

CREATE INDEX ix_wc_word
  ON wc(wordid);

CREATE INDEX ix_wc_class
  ON wc(wclassid);

CREATE TABLE mpy (
  mpyid   INTEGER PRIMARY KEY ASC,
  hanid   INTEGER NOT NULL
            REFERENCES han(hanid)
              ON DELETE CASCADE
              ON UPDATE CASCADE,
  mpyord  INTEGER NOT NULL,
  mpytrad TEXT NOT NULL,
  mpysimp TEXT NOT NULL,
  mpypny  TEXT NOT NULL,
  UNIQUE  (hanid, mpyord)
);

CREATE UNIQUE INDEX ix_mpy_rec
  ON mpy(hanid, mpyord);

CREATE INDEX ix_mpy_han
  ON mpy(hanid);

CREATE INDEX ix_mpy_trad
  ON mpy(mpytrad);

CREATE INDEX ix_mpy_simp
  ON mpy(mpysimp);

CREATE INDEX ix_mpy_pny
  ON mpy(mpypny);

CREATE TABLE dfn (
  dfnid   INTEGER PRIMARY KEY ASC,
  mpyid   INTEGER NOT NULL
            REFERENCES mpy(mpyid)
              ON DELETE CASCADE
              ON UPDATE CASCADE,
  dfnosen INTEGER NOT NULL,
  dfnogls INTEGER NOT NULL,
  dfntext TEXT NOT NULL,
  UNIQUE  (mpyid, dfnosen, dfnogls)
);

CREATE UNIQUE INDEX ix_dfn_rec
  ON dfn(mpyid, dfnosen, dfnogls);

CREATE INDEX ix_dfn_mpy
  ON dfn(mpyid);

};

# ==================
# Program entrypoint
# ==================

# Check that we didn't get any arguments
#
($#ARGV < 0) or die "Not expecting arguments, stopped";

# Open database connection to a new database
#
my $dbc = Sino::DB->connect($config_dbpath, 1);

# Begin r/w transaction and get handle
#
my $dbh = $dbc->beginWork('rw');

# Parse our SQL script into a sequence of statements, each ending with
# a semicolon
#
my @sql_list;
@sql_list = $sql_script =~ m/(.*?);/gs
  or die "Failed to parse SQL script, stopped";

# Run all the SQL statements needed to build the the database structure
#
for my $sql (@sql_list) {
  $dbh->do($sql);
}
  
# Commit the transaction
#
$dbc->finishWork;

=head1 AUTHOR

Noah Johnson, C<noah.johnson@loupmail.com>

=head1 COPYRIGHT AND LICENSE

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

=cut
