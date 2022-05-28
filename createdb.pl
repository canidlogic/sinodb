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
appropriate structure but no records.  Uses Sino::DB and SinoConfig, so
you must configure those two correctly before using this script.  See
the documentation in C<Sino::DB> for further information.

The database must not already exist or a fatal error occurs.

The SQL string embedded in this script contains the complete database
structure.  The following subsections describe the function of each
table within the database.

=head2 word table

The word table is the main list of words.  However, since nearly all of
the word fields can have multiple values, the word table only stores
fields that have a single value.  Currently, this is only C<wordlevel>,
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
       9     | Not covered by TOCFL

=head2 han table

The han table stores the Chinese characters for each word.  Each word
may have multiple Han readings.  The C<wordid> is a foreign key into the
C<word> table.  C<hanord> determines the ordering if there are multiple
versions for the same word.  C<hantrad> and C<hansimp> store the
traditional and simplified versions of the this variant.  If the
simplified version is the same as the traditional version, the
C<hansimp> field should duplicate the C<hantrad> field.  If the
simplified version is not known, then C<hansimp> should be NULL.  All
words should have at least one record in this table.

=head2 pny table

The pny table stores the Pinyin readings for each word.  Each word may
have multiple Pinyin readings.  The C<wordid> is a foreign key into the
C<word> table.  C<pnyord> determines the ordering if there are multiple
versions for the same word.  C<pnytext> is the actual Pinyin.  The
format used in the TOCFL data files is used in the Sino database, with
syllables written directly after on another, Unicode diacritics used for
tone marking, and everything lowercase.  All words should have at least
one record in this table.  Note that words with C<wordclass> 9 are based
on mainland pronunciation.

=head2 wclass table

The wclass table defines the full set of part-of-speech designations.
The names of the word classes must be unique.  Furthermore, each name
begins with an uppercase ASCII letter followed by a sequence of zero or
more additional characters, which must each be either lowercase ASCII
letters or hyphens.

=head2 wc table

The wc table associates part-of-speech designations with words.
C<wordid> is a foreign key into the C<word> table.  C<wcord> determines
the ordering if there are multiple part-of-speech designations for a
single word.  C<wclassid> is a foreign key into the C<wclass> table,
selecting the part-of-speech.  Some words do not have any word class
designation with them.

=head2 dfn table

The dfn table associates glosses and other additional information with
words.  (Note that Chinese characters may be used in these entries!)
C<wordid> is a foreign key into the C<word> table.  C<dfnsord> and
C<dfngord> provide a two-level ordering if there are multiple glosses.
The C<dfnsord> is the higher-level ordering, which indicates separate
senses of the word.  The C<dfngord> is the lower-level ordering, which
indicates separate glosses of the same sense of the word.  The actual
gloss is stored in the C<dfntext> field.

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
  hantrad TEXT NOT NULL,
  hansimp TEXT,
  UNIQUE  (wordid, hanord)
);

CREATE UNIQUE INDEX ix_han_rec
  ON han(wordid, hanord);

CREATE INDEX ix_han_word
  ON han(wordid);

CREATE INDEX ix_han_trad
  ON han(hantrad);

CREATE INDEX ix_han_simp
  ON han(hansimp);

CREATE TABLE pny (
  pnyid   INTEGER PRIMARY KEY ASC,
  wordid  INTEGER NOT NULL
            REFERENCES word(wordid)
              ON DELETE CASCADE
              ON UPDATE CASCADE,
  pnyord  INTEGER NOT NULL,
  pnytext TEXT NOT NULL,
  UNIQUE  (wordid, pnyord)
);

CREATE UNIQUE INDEX ix_pny_rec
  ON pny(wordid, pnyord);

CREATE INDEX ix_pny_word
  ON pny(wordid);

CREATE INDEX ix_pny_text
  ON pny(pnytext);

CREATE TABLE wclass (
  wclassid   INTEGER PRIMARY KEY ASC,
  wclassname TEXT UNIQUE NOT NULL
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

CREATE TABLE dfn (
  dfnid   INTEGER PRIMARY KEY ASC,
  wordid  INTEGER NOT NULL
            REFERENCES word(wordid)
              ON DELETE CASCADE
              ON UPDATE CASCADE,
  dfnsord INTEGER NOT NULL,
  dfngord INTEGER NOT NULL,
  dfntext TEXT NOT NULL,
  UNIQUE  (wordid, dfnsord, dfngord)
);

CREATE UNIQUE INDEX ix_dfn_rec
  ON dfn(wordid, dfnsord, dfngord);

CREATE INDEX ix_dfn_word
  ON dfn(wordid);

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