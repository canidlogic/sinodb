#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(encode);

# Sino imports
use Sino::DB;
use Sino::Util qw(parse_blocklist);
use SinoConfig;

=head1 NAME

import_coct.pl - Import data from COCT into the Sino database.

=head1 SYNOPSIS

  ./import_coct.pl

=head1 DESCRIPTION

This script is used to supplement a Sino database with words from the
COCT vocabulary data files.  This script should be your third step after
using C<import_tocfl.pl> to import all the TOCFL words.

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

There must be at least one word already defined.  This script will
expand each word in the COCT vocabulary list into all its Han variant
forms.  If any of the variant forms are already in the Sino database,
the whole COCT word is skipped.  Otherwise, it is added as a new word
into the database, with all of the Han readings, and at a level one
greater than the level in the COCT data file (since COCT levels are one
higher than TOCFL).

Also, this script will skip all COCT records where I<all> headwords are
on the blocklist as defined by the C<parse_blocklist> function of
C<Sino::Util>.

=cut

# ===============
# Local functions
# ===============

# han_addifnew(dbc, wordid, hantrad)
#
# Given a Sino::DB database connection, a wordid, and a Han traditional
# character rendering, add it as a Han reading of the given wordid
# unless it is already present in the han table.  In all cases, return a
# hanid corresponding to this reading.
#
# This function does not check that the given wordid actually exists in
# the word table, and it does not check that hantrad is unique within
# the han table before inserting it.
#
sub han_addifnew {
  # Get and check parameters
  ($#_ == 2) or die "Wrong parameter count, stopped";
  
  my $dbc = shift;
  (ref($dbc) and $dbc->isa('Sino::DB')) or
    die "Wrong parameter type, stopped";
  
  my $wordid  = shift;
  my $hantrad = shift;
  
  ((not ref($wordid)) and (not ref($hantrad))) or
    die "Wrong parameter type, stopped";
  
  (int($wordid) == $wordid) or
    die "Wrong parameter type, stopped";
  $wordid = int($wordid);
  ($wordid >= 0) or die "Parameter out of range, stopped";
  
  # Encode traditional reading in binary, in-place OK
  $hantrad = encode('UTF-8', $hantrad, Encode::FB_CROAK);
  
  # Start a read/write work block
  my $dbh = $dbc->beginWork('rw');
  
  # Find whether the given traditional reading already exists for this
  # word, and get its ID if it does
  my $han_id = $dbh->selectrow_arrayref(
                'SELECT hanid FROM han WHERE wordid=? AND hantrad=?',
                undef,
                $wordid, $hantrad);
  if (ref($han_id) eq 'ARRAY') {
    $han_id = $han_id->[0];
  } else {
    $han_id = undef;
  }
  
  # Proceed if we didn't find an existing reading
  if (not defined $han_id) {
    # Get the next ord for this wordid in the han table, or 1 if no
    # records yet
    my $han_ord = $dbh->selectrow_arrayref(
                    'SELECT hanord FROM han WHERE wordid=? '
                    . 'ORDER BY hanord DESC',
                    undef,
                    $wordid);
    if (ref($han_ord) eq 'ARRAY') {
      $han_ord = $han_ord->[0] + 1;
    } else {
      $han_ord = 1;
    }
    
    # Insert into table
    $dbh->do(
        'INSERT INTO han(wordid, hanord, hantrad) VALUES (?,?,?)',
        undef,
        $wordid, $han_ord, $hantrad);
    
    # Get hanid of record
    $han_id = $dbh->selectrow_arrayref(
                'SELECT hanid FROM han WHERE wordid=? AND hanord=?',
                undef,
                $wordid, $han_ord);
    (ref($han_id) eq 'ARRAY') or die "Unexpected";
    $han_id = $han_id->[0];
  }
  
  # Finish the work block if we got here
  $dbc->finishWork;
  
  # Return the ID
  return $han_id;
}

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

# Check that there are no program arguments
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Check that COCT data file exists
#
(-f $config_coctpath) or
  die "Can't find COCT file '$config_coctpath', stopped";

# Load the blocklist
#
my $blocklist = parse_blocklist($config_datasets);

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read-write transaction for everything
#
my $dbh = $dbc->beginWork('rw');

# Check that at least one word already defined
#
my $ecq = $dbh->selectrow_arrayref('SELECT wordid FROM word');
(ref($ecq) eq 'ARRAY') or
  die "Database doesn't have any words defined yet, stopped";

# Open the COCT file for reading in UTF-8 with CR+LF translation
#
open(my $fh, "< :encoding(UTF-8) :crlf", $config_coctpath) or
  die "Failed to open '$config_coctpath', stopped";

# Now read line-by-line
#
my $lnum = 0;
while (my $ltext = readline($fh)) {
  # Increase line counter
  $lnum++;

  # If this is very first line of file, drop any UTF-8 Byte Order Mark
  # (BOM) from the start
  if ($lnum == 1) {
    $ltext =~ s/\A\x{feff}//;
  }
  
  # Drop line break if present
  chomp $ltext;
  
  # Normalize variant parentheses into ASCII parentheses
  $ltext =~ s/\x{ff08}/\(/g;
  $ltext =~ s/\x{ff09}/\)/g;
  
  # Normalize variant slash into ASCII slash
  $ltext =~ s/\x{ff0f}/\//g;
  
  # Parse into two fields with comma separator
  my @rec = split /,/, $ltext;
  ($#rec == 1) or
    die "Line $lnum: Wrong number of fields, stopped";
  
  # For each field, trim leading and trailing whitespace, then drop
  # leading and trailing quotes if present, then trim leading and
  # trailing whitespace again
  for my $fv (@rec) {
    $fv =~ s/\A[ \t]*(?:["'][ \t]*)?//;
    $fv =~ s/(?:[ \t]*["'])?[ \t]*\z//;
  }

  # Determine level
  ($rec[0] =~ /\A[^0-9]*([0-9]+)[^0-9]*\z/) or
    die "Line $lnum: Invalid level, stopped";
  my $coct_level = int($1);

  # Get sequence of headwords
  my @hwsa  = split /\//, $rec[1];
  
  # For headwords, elements that have a parenthetical should be split
  # into two separate entries, one with the parenthetical and one
  # without; we will create new array @hws that store the expanded
  # entries
  my @hws;
    
  # Go through each element in the source array and either copy as-is to
  # target array or split into two elements in target array; also, do
  # duplication checks so that duplicates are never inserted while
  # decoding; furthermore, drop any digit sequences at the end of words
  for my $sv (@hwsa) {
    # Handle cases
    if ($sv =~ /\A
                  ([^\(\)0-9]*)
                  \(
                  ([^\(\)0-9]*)
                  \)
                  ([^\(\)0-9]*)
                  (?:\s*[0-9]+)?
                \z/x) {
      # Single parenthetical, so split into prefix optional suffix
      my $prefix = $1;
      my $option = $2;
      my $suffix = $3;
      
      # Whitespace-trim each
      $prefix =~ s/\A[ \t]+//;
      $prefix =~ s/[ \t]+\z//;
      
      $option =~ s/\A[ \t]+//;
      $option =~ s/[ \t]+\z//;
      
      $suffix =~ s/\A[ \t]+//;
      $suffix =~ s/[ \t]+\z//;
      
      # Make sure option is not empty after trimming
      (length($option) > 0) or
        die "Line $lnum: Empty optional, stopped";
      
      # Make sure either prefix or suffix (or both) is non-empty
      ((length($prefix) > 0) or (length($suffix) > 0)) or
        die "Line $lnum: Invalid optional, stopped";
      
      # Insert both without and with the optional, but only if not
      # already in the target array
      for my $iv ($prefix . $suffix, $prefix . $option . $suffix) {
        my $dup_found = 0;
        for my $dvc (@hws) {
          if ($iv eq $dvc) {
            $dup_found = 1;
            last;
          }
        }
        unless ($dup_found) {
          push @hws, ($iv);
        }
      }
      
    } elsif ($sv =~ /\A([^\(\)0-9]*)(?:\s*[0-9]+)?\z/) {
      # No parentheticals, so begin by dropping numeric suffix if
      # present
      my $sw = $1;
      
      # Whitespace trimming
      $sw =~ s/\A[ \t]+//;
      $sw =~ s/[ \t]+\z//;
      
      # Make sure after trimming not empty
      (length($sw) > 0) or
        die "Line $lnum: Empty component, stopped";
      
      # Push into target array, but only if not already in the target
      # array
      my $dup_found = 0;
      for my $dvc (@hws) {
        if ($sw eq $dvc) {
          $dup_found = 1;
          last;
        }
      }
      unless ($dup_found) {
        push @hws, ($sw);
      }
      
    } else {
      # Other cases are invalid
      die "Line $lnum: Invalid record, stopped";
    }
  }
  
  # Go through all the headwords and make sure only characters of 
  # General Category Letter-Other (Lo) are used
  for my $fv (@hws) {
    ($fv =~ /\A[\p{Lo}]+\z/) or
      die "Line $lnum: Invalid headword char, stopped";
  }
  
  # If all the headwords are on the blocklist, then skip this COCT
  # record
  my $is_blocked = 1;
  for my $hwv (@hws) {
    unless (defined $blocklist->{$hwv}) {
      $is_blocked = 0;
      last;
    }
  }
  (not $is_blocked) or next;
  
  # Look through all the headwords and determine whether any existing
  # words share any of those headwords
  my $is_shared = 0;
  for my $hwv (@hws) {
    my $qck = $dbh->selectrow_arrayref(
                  'SELECT wordid FROM han WHERE hantrad=?',
                  undef,
                  encode('UTF-8', $hwv,
                          Encode::FB_CROAK | Encode::LEAVE_SRC));
    if (ref($qck) eq 'ARRAY') {
      $is_shared = 1;
      last;
    }
  }
  
  # If any of the headwords are shared, skip this record
  (not $is_shared) or next;
  
  # Insert a brand-new word; determine new word ID as one greater than
  # greatest existing, or 1 if this is the first
  my $wordid = wordid_new($dbc);
  
  # Insert the new word record, with level one greater than COCT level
  $dbh->do('INSERT INTO word(wordid, wordlevel) VALUES (?,?)',
            undef,
            $wordid, $coct_level + 1);
  
  # Add all Han readings
  for my $hwv (@hws) {
    han_addifnew($dbc, $wordid, $hwv);
  }
}

# Close the file
close($fh);

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
