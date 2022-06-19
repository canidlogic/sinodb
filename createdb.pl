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
merged word has the minimum C<wordlevel> of the words being merged.

=head2 han table

The han table stores the Han characters for each word.  Each word may
have multiple Han readings.  The C<wordid> is a foreign key into the
C<word> table.  C<hanord> determines the ordering if there are multiple
versions for the same word.  C<hantrad> stores the traditional
characters.

The C<hantrad> field must be unique, so that two different words are
I<not> allowed to have the same Han character rendering.  This does
happen sometimes in the TOCFL dataset, in which case words are merged
together.

When different TOCFL source words are merged together, the merged word
has all the unique Han renderings across the merged words.

=head2 pny table

The pny table stores the Pinyin readings for each Han reading in the
C<han> table.  These Pinyin readings are taken only from the TOCFL data
files, so they should all be for Taiwan Mandarin.  Each Han reading may
have multiple Pinyin readings.  The C<hanid> is a foreign key into the
C<han> table.  C<pnyord> determines the ordering if there are multiple
Pinyin readings for the same Han reading.  C<pnytext> is the actual
Pinyin.  The Pinyin is normalized into standard form (see C<pinyin.md>
for details of the standard format).

When different TOCFL source words are merged together, the merged word
has all the unique Pinyin renderings of all the unique Han readings
across the merged words.

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

=head2 ref table

The ref table stores CC-CEDICT reference entities.  Each reference
entity must have a traditional Han reading and a simplified Han reading.
(If traditional and simplified are the same, then both fields should
have the same value.)  The traditional field is C<reftrad> and the
simplified field is C<refsimp>.

A reference entity may optionally have a Pinyin reading.  If present,
the Pinyin reading is stored in C<refpny> and must be in normalized form
(see C<pinyin.md>).  If not present, the field may be NULL.  Note that
reference entity Pinyin generally uses mainland pronunications rather
than Taiwanese.

=head2 mpy table

The mpy table stores the top-level definition records from CC-CEDICT
that will be associated with Han characters.  Each record in this table
corresponds to a single record in the CC-CEDICT dictionary file.  Since
there may be multiple records in CC-CEDICT for each Han reading, this
table allows for multiple definitions for each Han reading, with
C<mpyord> used to order each of these definition records.

This table also stores additional data from the CC-CEDICT dictionary
that is specific to individual records.  There is a foreign key into the
ref table that defines the traditional, simplified, and Pinyin readings
of this particular record as they appear in CC-CEDICT.  (NULL is used
for Pinyin when the Pinyin in CC-CEDICT fails to normalize.)  Also, the
C<mpyprop> field is 1 if the original CC-CEDICT Pinyin had any uppercase
letters in it (indicating a proper name entry), else zero.

In a few cases, the TOCFL/COCT word list uses Han forms that are
considered simplified in CC-CEDICT, so in those cases the Han from the
C<han> table will match with the simplified reading in the reference
entity rather than the traditional one.

=head2 dfn table

The dfn table associates glosses from CC-CEDICT with definition records
in the C<mpy> table.  C<mpyid> is a foreign key into that table.

When there are multiple glosses for an C<mpy> record, C<dfnord> is used
to establish an ordering for them.

There is also a C<dfnsen> field which indicates the sense number.
Glosses when ordered by C<dfnsen> will be in the same order as for the
C<dfnord> field, except that there might be multiple glosses with the
same sense number.

Example of C<dfnord> and C<dfnsen>:

   dfnsen | dfnord |                    dfntext
  ========+========+===============================================
      1   |    1   | complete change from the normal state (idiom)
      1   |    2   | quite uncharacteristic
      2   |    3   | entirely outside the norm
      3   |    4   | out of character

In this example, the first two glosses are both part of the same sense,
while the last two glosses are each their own sense.

C<dfntext> gives the gloss text.  However, classifier glosses, alternate
pronunciation glosses, and cross-reference glosses have already been
extracted and are not present in the gloss text.  No glosses with empty
gloss text are allowed.

=head2 cit table

The cit table annotates glosses in the dfn table with citations.
Citations reference a substring of a specific gloss and provide a parsed
representation of it.

Each record in this table has a foreign key into the dfn table, and then
C<citoff> and C<citlen> fields defining the codepoint starting offset
and codepoint length of the citation within the gloss.  Each record also
has a foreign key into the ref table which specifies the parsed form of
the citation.

=head2 msm and msd tables

The msm and msd tables define measure words (also known as classifiers)
and associate them with records in the C<mpy> and C<dfn> tables.  The
only difference between msm and msd is that msm links to the C<mpy>
table and msd links to the C<dfn> table.

Both tables contain a foreign key defining what they are annotating
(C<mpyid> or C<dfnid>).  Both tables have an C<msmord> or C<msdord>
field that orders measure words when there are multiple measure word
annotations on the same entity.  Finally, both tables have a foreign key
into the C<ref> table that identifies the specific classifier.

=head2 atm table

The atm table defines atom strings that are used in pronunciation and
cross-reference glosses.  Since there is a lot of repetition in these
values, it makes sense to have an atom table.

C<atmid> lets atoms be referenced by a foreign key, while C<atmval> is
the actual text of the atom, which may be an empty string.  However,
C<atmval> must be unique within the atom table.

=head2 apm and apd tables

The apm and apd tables define alternate pronunications and associate
them with records in the C<mpy> and C<dfn> tables.  The only difference
between apm and apd is that apm links to the C<mpy> table and apd links
to the C<dfn> table.

Both tables contain a foreign key defining what they are annotating
(C<mpyid> or C<dfnid>).  Both tables have an C<apmord> or C<apdord>
field that orders pronunciations when there are multiple pronunciation
annotations on the same entity.  Both tables have a C<apmpny> or
C<apdpny> field that stores the Pinyin for the alternate pronunciation,
normalized according to C<pinyin.md>.  Finally, both tables have
C<ctx> and C<cond> fields specifying the context and condition in which
the alternate pronunication is used.  Both of these fields are foreign
keys into the atm table.

=head2 xrm and xrd tables

The xrm and xrd tables define cross-references and associate them with
records in the C<mpy> and C<dfn> tables.  The only difference between
xrm and xrd is that xrm links to the C<mpy> table and xrd links to the
C<dfn> table.

Both tables contain a foreign key defining what they are annotating
(C<mpyid> or C<dfnid>).  Both tables have an C<ord> field that orders
cross-references when there are multiple cross-reference annotations on
the same entity.  Both tables have a foreign key into the ref table
identifying the cross-reference.  Finally, both tables have C<desc>
C<type> and C<suf> fields specifying the cross-reference descriptor,
the cross-reference type, and the cross-reference suffix.  Each of these
three final fields are foreign keys into the atm table.

=head2 tok and tkm tables

The tok and tkm tables are used for searching through the glosses for
token keywords.

The tok table defines unique search tokens.  Search tokens are sequences
of one or more ASCII lowercase letters, with apostrophe allowed between
two letters.  Tokens are case insensitive and also diacritic marks on
Latin letters should be removed.

The tkm table defines the token content of each gloss.  There is also a
C<pos> field, which indicates the position of the token within the
gloss.  A position of zero means the token is the first token in the
gloss, a position of one means the second token in the gloss, and so
forth.

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

CREATE TABLE ref (
  refid   INTEGER PRIMARY KEY ASC,
  reftrad TEXT NOT NULL,
  refsimp TEXT NOT NULL,
  refpny  TEXT,
  UNIQUE  (reftrad, refsimp, refpny)
);

CREATE UNIQUE INDEX ix_ref_rec
  ON ref(reftrad, refsimp, refpny);

CREATE INDEX ix_ref_trad
  ON ref(reftrad);

CREATE TABLE mpy (
  mpyid   INTEGER PRIMARY KEY ASC,
  hanid   INTEGER NOT NULL
            REFERENCES han(hanid)
              ON DELETE CASCADE
              ON UPDATE CASCADE,
  mpyord  INTEGER NOT NULL,
  refid   INTEGER NOT NULL
            REFERENCES ref(refid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  mpyprop INTEGER NOT NULL,
  UNIQUE  (hanid, mpyord)
);

CREATE UNIQUE INDEX ix_mpy_rec
  ON mpy(hanid, mpyord);

CREATE INDEX ix_mpy_han
  ON mpy(hanid);

CREATE INDEX ix_mpy_ref
  ON mpy(refid);

CREATE TABLE dfn (
  dfnid   INTEGER PRIMARY KEY ASC,
  mpyid   INTEGER NOT NULL
            REFERENCES mpy(mpyid)
              ON DELETE CASCADE
              ON UPDATE CASCADE,
  dfnord  INTEGER NOT NULL,
  dfnsen  INTEGER NOT NULL,
  dfntext TEXT NOT NULL,
  UNIQUE  (mpyid, dfnord)
);

CREATE UNIQUE INDEX ix_dfn_rec
  ON dfn(mpyid, dfnord);

CREATE INDEX ix_dfn_mpy
  ON dfn(mpyid);

CREATE TABLE cit (
  citid   INTEGER PRIMARY KEY ASC,
  dfnid   INTEGER NOT NULL
            REFERENCES dfn(dfnid)
              ON DELETE CASCADE
              ON UPDATE CASCADE,
  citoff  INTEGER NOT NULL,
  citlen  INTEGER NOT NULL,
  refid   INTEGER NOT NULL
            REFERENCES ref(refid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  UNIQUE  (dfnid, citoff)
);

CREATE UNIQUE INDEX ix_cit_rec
  ON cit(dfnid, citoff);

CREATE INDEX ix_cit_gloss
  ON cit(dfnid);

CREATE INDEX ix_cit_ref
  ON cit(refid);

CREATE TABLE msm (
  msmid   INTEGER PRIMARY KEY ASC,
  mpyid   INTEGER NOT NULL
            REFERENCES mpy(mpyid)
              ON DELETE CASCADE
              ON UPDATE CASCADE,
  msmord  INTEGER NOT NULL,
  refid   INTEGER NOT NULL
            REFERENCES ref(refid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  UNIQUE  (mpyid, msmord)
);

CREATE UNIQUE INDEX ix_msm_rec
  ON msm(mpyid, msmord);

CREATE INDEX ix_msm_mpy
  ON msm(mpyid);

CREATE INDEX ix_msm_ref
  ON msm(refid);

CREATE TABLE msd (
  msdid   INTEGER PRIMARY KEY ASC,
  dfnid   INTEGER NOT NULL
            REFERENCES dfn(dfnid)
              ON DELETE CASCADE
              ON UPDATE CASCADE,
  msdord  INTEGER NOT NULL,
  refid   INTEGER NOT NULL
            REFERENCES ref(refid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  UNIQUE  (dfnid, msdord)
);

CREATE UNIQUE INDEX ix_msd_rec
  ON msd(dfnid, msdord);

CREATE INDEX ix_msd_dfn
  ON msd(dfnid);

CREATE INDEX ix_msd_ref
  ON msd(refid);

CREATE TABLE atm (
  atmid  INTEGER PRIMARY KEY ASC,
  atmval TEXT UNIQUE NOT NULL
);

CREATE UNIQUE INDEX ix_atm_val
  ON atm(atmval);

CREATE TABLE apm (
  apmid   INTEGER PRIMARY KEY ASC,
  mpyid   INTEGER NOT NULL
            REFERENCES mpy(mpyid)
              ON DELETE CASCADE
              ON UPDATE CASCADE,
  apmord  INTEGER NOT NULL,
  apmctx  INTEGER NOT NULL
            REFERENCES atm(atmid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  apmcond INTEGER NOT NULL
            REFERENCES atm(atmid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  apmpny  TEXT NOT NULL,
  UNIQUE  (mpyid, apmord)
);

CREATE UNIQUE INDEX ix_apm_rec
  ON apm(mpyid, apmord);

CREATE INDEX ix_apm_mpy
  ON apm(mpyid);

CREATE INDEX ix_apm_pny
  ON apm(apmpny);

CREATE TABLE apd (
  apdid   INTEGER PRIMARY KEY ASC,
  dfnid   INTEGER NOT NULL
            REFERENCES dfn(dfnid)
              ON DELETE CASCADE
              ON UPDATE CASCADE,
  apdord  INTEGER NOT NULL,
  apdctx  INTEGER NOT NULL
            REFERENCES atm(atmid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  apdcond INTEGER NOT NULL
            REFERENCES atm(atmid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  apdpny  TEXT NOT NULL,
  UNIQUE  (dfnid, apdord)
);

CREATE UNIQUE INDEX ix_apd_rec
  ON apd(dfnid, apdord);

CREATE INDEX ix_apd_dfn
  ON apd(dfnid);

CREATE INDEX ix_apd_pny
  ON apd(apdpny);

CREATE TABLE xrm (
  xrmid   INTEGER PRIMARY KEY ASC,
  mpyid   INTEGER NOT NULL
            REFERENCES mpy(mpyid)
              ON DELETE CASCADE
              ON UPDATE CASCADE,
  xrmord  INTEGER NOT NULL,
  refid   INTEGER NOT NULL
            REFERENCES ref(refid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  xrmdesc INTEGER NOT NULL
            REFERENCES atm(atmid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  xrmtype INTEGER NOT NULL
            REFERENCES atm(atmid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  xrmsuf  INTEGER NOT NULL
            REFERENCES atm(atmid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  UNIQUE  (mpyid, xrmord)
);

CREATE UNIQUE INDEX ix_xrm_rec
  ON xrm(mpyid, xrmord);

CREATE INDEX ix_xrm_mpy
  ON xrm(mpyid);

CREATE INDEX ix_xrm_ref
  ON xrm(refid);

CREATE TABLE xrd (
  xrdid   INTEGER PRIMARY KEY ASC,
  dfnid   INTEGER NOT NULL
            REFERENCES dfn(dfnid)
              ON DELETE CASCADE
              ON UPDATE CASCADE,
  xrdord  INTEGER NOT NULL,
  refid   INTEGER NOT NULL
            REFERENCES ref(refid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  xrddesc INTEGER NOT NULL
            REFERENCES atm(atmid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  xrdtype INTEGER NOT NULL
            REFERENCES atm(atmid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  xrdsuf  INTEGER NOT NULL
            REFERENCES atm(atmid)
              ON DELETE RESTRICT
              ON UPDATE RESTRICT,
  UNIQUE  (dfnid, xrdord)
);

CREATE UNIQUE INDEX ix_xrd_rec
  ON xrd(dfnid, xrdord);

CREATE INDEX ix_xrd_dfn
  ON xrd(dfnid);

CREATE INDEX ix_xrd_ref
  ON xrd(refid);

CREATE TABLE tok (
  tokid  INTEGER PRIMARY KEY ASC,
  tokval TEXT UNIQUE NOT NULL
);

CREATE UNIQUE INDEX ix_tok_val
  ON tok(tokval);

CREATE TABLE tkm (
  tkmid   INTEGER PRIMARY KEY ASC,
  tokid   INTEGER NOT NULL
            REFERENCES tok(tokid)
              ON DELETE RESTRICT
              ON UPDATE CASCADE,
  dfnid   INTEGER NOT NULL
            REFERENCES dfn(dfnid)
              ON DELETE RESTRICT
              ON UPDATE CASCADE,
  tkmpos  INTEGER NOT NULL,
  UNIQUE  (tokid, dfnid, tkmpos)
);

CREATE UNIQUE INDEX ix_tkm_rec
  ON tkm(tokid, dfnid, tkmpos);

CREATE INDEX ix_tkm_tok
  ON tkm(tokid);

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
