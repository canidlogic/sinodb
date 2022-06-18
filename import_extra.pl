#!/usr/bin/env perl
use strict;
use warnings;

# Sino imports
use Sino::DB;
use Sino::Multifile;
use Sino::Op qw(
                string_to_db
                wordid_new
                enter_han);
use SinoConfig;

=head1 NAME

import_extra.pl - Import supplemental words into the Sino database.

=head1 SYNOPSIS

  ./import_extra.pl

=head1 DESCRIPTION

This script is used to import supplemental words into a Sino database.

The supplemental datafile C<level9.txt> is consulted, and all headwords
there are added as words into the C<word> and C<han> tables, with each
headword being a separate word and the wordlevel of each being set to 9.
This script verifies that none of the headwords in C<level9.txt> are
already in the database, failing if any are already present.

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

=cut

# ==================
# Program entrypoint
# ==================

# Switch error report to UTF-8
#
binmode(STDERR, ":encoding(UTF-8)") or
  die "Failed to set UTF-8 output, stopped";

# Check that there are no program arguments
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Get path to level9.txt data file
#
my $level9_path = $config_datasets . 'level9.txt';

# Check that level9.txt data file exists
#
(-f $level9_path) or
  die "Can't find level9 file '$level9_path', stopped";

# Open a multifile reader on the level9.txt data file
#
my $mr = Sino::Multifile->load([$level9_path]);

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read-write transaction for everything
#
my $dbh = $dbc->beginWork('rw');

# Add all new headwords, checking they are not already present
#
while ($mr->advance) {
  
  # Get line number for diagnostics
  my $lnum = $mr->line_number;
  
  # Get line just read
  my $ltext = $mr->text;
  
  # Ignore line if blank
  (not ($ltext =~ /\A\s*\z/)) or next;
  
  # Parse headword
  ($ltext =~ /\A\s*([\x{4e00}-\x{9fff}]+)\s*\z/) or
    die "level9.txt line $lnum: Invalid record, stopped";
  my $hword = $1;
  
  # Get binary string version
  my $hword_enc = string_to_db($hword);
  
  # Verify that not already in table
  my $qr = $dbh->selectrow_arrayref(
                    'SELECT hanid FROM han WHERE hantrad=?',
                    undef,
                    $hword_enc);
  (not (ref($qr) eq 'ARRAY')) or
    die "Headword '$hword' already in database, stopped";
  
  # Get a new word ID
  my $word_id = wordid_new($dbc);
  
  # Add a level 9 entry for this word
  $dbh->do('INSERT INTO word(wordid, wordlevel) VALUES (?,?)',
            undef,
            $word_id, 9);
  
  # Add the Han reading for this word
  enter_han($dbc, $word_id, $hword);
}

# If we got here, commit all our changes as a single transaction
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
