#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(encode);

# Sino imports
use Sino::DB;
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

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

=cut

# ===============
# Local functions
# ===============

# wordid_new(dbc)
#
# Given a Sino::DB database connection, figure out a new word ID to use.
# A race will occur unless you call this function in a work block that
# is already open.
#
sub wordid_new {
  # Get and check parameter
  ($#_ == 0) or die "Wrong parameter count, stopped";
  my $dbc = shift;
  (ref($dbc) and $dbc->isa('Sino::DB')) or
    die "Wrong parameter type, stopped";
  
  # Start a read work block
  my $dbh = $dbc->beginWork('r');
  
  # Find the maximum word ID currently in use
  my $wordid = $dbh->selectrow_arrayref(
                      'SELECT wordid FROM word ORDER BY wordid DESC');
  
  # If we got any word records, return one greater than the greatest
  # one, else return 1 for the first word record
  if (ref($wordid) eq 'ARRAY') {
    $wordid = $wordid->[0] + 1;
  } else {
    $wordid = 1;
  }
  
  # If we got here, finish the read work block
  $dbc->finishWork;
  
  # Return result
  return $wordid;
}

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
my $level9_path = $config_datasets . 'level9.txt';

# Check that level9.txt data file exists
#
(-f $level9_path) or
  die "Can't find level9 file '$level9_path', stopped";

# Open for reading in UTF-8 with CR+LF conversion, and read all
# non-blank lines into a headword array
#
open(my $fh, "< :encoding(UTF-8) :crlf", $level9_path) or
  die "Failed to open '$level9_path', stopped";

# Now read line-by-line
#
my @hwords;
my $lnum = 0;
while (not eof($fh)) {
  # Increment line number
  $lnum++;
  
  # Read a line
  my $ltext = readline($fh);
  (defined $ltext) or die "I/O error, stopped";
  
  # Drop line break
  chomp $ltext;
  
  # If very first line, drop any UTF-8 BOM
  if ($lnum == 1) {
    $ltext =~ s/\A\x{feff}//;
  }
  
  # Ignore line if blank
  (not ($ltext =~ /\A\s*\z/)) or next;
  
  # Parse headword
  ($ltext =~ /\A\s*([\p{Lo}]+)\s*\z/) or
    die "level9.txt line $lnum: Invalid record, stopped";
  my $hword = $1;
  
  # Add headword to array
  push @hwords, ($hword);
}

# Close the datafile
#
close($fh);

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read-write transaction for everything
#
my $dbh = $dbc->beginWork('rw');

# Add all headwords if not already present
#
for my $hword (@hwords) {
  
  # Get encoded version
  my $hword_enc = encode('UTF-8', $hword,
                          Encode::FB_CROAK | Encode::LEAVE_SRC);
  
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
  $dbh->do('INSERT INTO han(wordid, hanord, hantrad) VALUES (?,?,?)',
            undef,
            $word_id, 1, $hword_enc);
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
