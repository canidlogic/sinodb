#!/usr/bin/env perl
use strict;
use warnings;

# Sino imports
use Sino::DB;
use Sino::Dict;
use Sino::Op qw(
              string_to_db
              enter_ref
              enter_atom);
use SinoConfig;

=head1 NAME

import_cedict.pl - Import data from CC-CEDICT into the Sino database.

=head1 SYNOPSIS

  ./import_cedict.pl

=head1 DESCRIPTION

This script is used to fill a Sino database with information derived
from the CC-CEDICT data file.  

You should only use this script after you've added all words with the
other import scripts.  This script will only add definitions for words
that already exist in the database.  You must have at least one word
defined already in the database or this script will fail.

This script performs four passes through the CC-CEDICT database.  Each
pass it only examines certain types of CC-CEDICT records, and each pass
it only processes records for which the headword is not already defined
in the database.  In this way, the passes are a fallback system, where
records from pass two are only imported for words that were not handled
in pass one, records from pass three are only imported for words that
were not handled in passes one and two, and records from pass four are
only imported for words that were not handled in passes one, two, and
three.  The four passes have the following characteristics:

   Pass | CC-CEDICT matching | Entry type
  ======+====================+============
     1  |    traditional     |   common
     2  |    simplified      |   common
     3  |    traditional     |   proper
     4  |    simplified      |   proper

With this scheme, CC-CEDICT records for proper names (that is, where the
original CC-CEDICT Pinyin contains at least one uppercase ASCII letter)
are not consulted for words unless all attempts to find definitions
amongst records that are not proper names have failed.  Also, if
matching against traditional Han readings in the CC-CEDICT fails,
matching against simplified Han readings will then be attempted as a
fallback, to handle cases where the TOCFL/COCT headwords use a rendering
that CC-CEDICT considers to be simplified.

Since this is a long process, regular progress reports are printed out
on standard error as the script is running.  At the end, a summary
screen is printed on standard output, indicating how many records were
added in each pass.

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

=cut

# ==================
# Program entrypoint
# ==================

# Check that we got no program arguments
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read-write transaction for everything
#
my $dbh = $dbc->beginWork('rw');

# Check that there is at least one word
#
my $edck = $dbh->selectrow_arrayref('SELECT wordid FROM word');
(ref($edck) eq 'ARRAY') or die "No words defined in database, stopped";

# Load the CC-CEDICT dictionary
#
my $dict = Sino::Dict->load($config_dictpath, $config_datasets);

# Define array that will store how many records added in each pass
#
my @pass_results;

# Make four passes through the dictionary
#
for(my $pass = 0; $pass < 4; $pass++) {
  
  # Define the current word hash for use in the current pass, where it
  # will map word IDs added during the current pass to a value of 1;
  # this allows a pass to determine whether a word ID was already
  # present in previous passes (in which case it is NOT in the hash)
  # versus word IDs that were added in the current pass
  my %current_hash;
  
  # Define the pass_progress counter, which counts the number of records
  # added within this pass, and the pass_scan counter, which counts all
  # the records scanned in this pass so far, and the pass_time
  # timestamp, which is the current time
  my $pass_progress = 0;
  my $pass_scan     = 0;
  my $pass_time     = time();
  
  # Report the start of the pass
  printf { \*STDERR } "Starting pass %d...\n", $pass + 1;
  
  # Define the match_simp flag, which is 1 on second and fourth passes
  # (meaning match with CC-CEDICT simplified headword) and 0 on first
  # and third passes (meaning match with CC-CEDICT traditional headword)
  my $match_simp = 0;
  if (($pass % 2) == 1) {
    $match_simp = 1;
  }
  
  # Define the match_prop flag, which is 1 on third and fourth passes
  # (meaning match CC-CEDICT proper name entries) and 0 on first and
  # second passes (meaning match anything but CC-CEDICT proper name
  # entries)
  my $match_prop = 0;
  if ($pass >= 2) {
    $match_prop = 1;
  }
  
  # Go through each dictionary record
  $dict->rewind;
  while ($dict->advance) {
    # Update pass_scan counter
    $pass_scan++;
    
    # If five seconds have passed, print a progress report
    if (time() - $pass_time >= 5) {
      $pass_time = time();
      printf { \*STDERR } "Pass %d: Scanned %d records\n",
                            $pass + 1, $pass_scan;
    }
    
    # Skip records depending on the state of the match_prop flag
    if ($match_prop) {
      unless ($dict->is_proper) {
        next;
      }
    } else {
      if ($dict->is_proper) {
        next;
      }
    }
    
    # Depending on the pass, we will search CC-CEDICT either for the
    # traditional or the simplified Han rendering of the record
    my $char_search;
    if ($match_simp) {
      $char_search = $dict->simplified;
                        
    } else {
      $char_search = $dict->traditional;
    }
    
    # Seek the hanid and word ID corresponding to this dictionary
    # record, or skip this record if there is no hanid
    my $qr = $dbh->selectrow_arrayref(
              'SELECT hanid, wordid FROM han WHERE hantrad=?',
              undef,
              string_to_db($char_search));
    (ref($qr) eq 'ARRAY') or next;
    my $hanid   = $qr->[0];
    my $word_id = $qr->[1];
    
    # If this word is not in the current hash, skip it unless there are
    # no records for any of its Han renderings yet in the mpy table
    unless (defined $current_hash{"$word_id"}) {
      $qr = $dbh->selectrow_arrayref(
              'SELECT mpyid '
              . 'FROM mpy '
              . 'INNER JOIN han ON han.hanid = mpy.hanid '
              . 'WHERE wordid=?',
              undef,
              $word_id);
      if (ref($qr) eq 'ARRAY') {
        next;
      }
    }
    
    # If we got here, we are going to add this record to the database,
    # so begin by adding it to the current hash and incrementing the
    # progress counter
    $current_hash{"$word_id"} = 1;
    $pass_progress++;
    
    # Get a reference ID for the main mpy record
    my $mpy_refid = enter_ref(
                        $dbc,
                        $dict->traditional,
                        $dict->simplified,
                        $dict->pinyin);
    
    # Determine the mpy order number for this dictionary record as one
    # greater than the previous for this Han character, or 1 if no
    # previous
    my $mpy_order = 1;
    $qr = $dbh->selectrow_arrayref(
            'SELECT mpyord FROM mpy WHERE hanid=? '
            . 'ORDER BY mpyord DESC',
            undef,
            $hanid);
    if (ref($qr) eq 'ARRAY') {
      $mpy_order = $qr->[0] + 1;
    }
    
    # Get the mpy_id for a new record as one greater than the greatest
    # current ID, or 1 if no records in the mpy table yet
    my $mpy_id = 1;
    $qr = $dbh->selectrow_arrayref(
                  'SELECT mpyid FROM mpy ORDER BY mpyid DESC');
    if (ref($qr) eq 'ARRAY') {
      $mpy_id = $qr->[0] + 1;
    }
    
    # Insert the mpy record for this dictionary record
    $dbh->do(
          'INSERT INTO mpy(mpyid, hanid, mpyord, refid, mpyprop) '
          . 'VALUES (?, ?, ?, ?, ?)',
          undef,
          $mpy_id,
          $hanid,
          $mpy_order,
          $mpy_refid,
          $match_prop);
    
    # Get record-level annotations, which we will be adding first
    my $rla = $dict->main_annote;
    
    # Add any record-level measure-word/classifiers
    for(my $i = 0; $i < scalar(@{$rla->{'measures'}}); $i++) {
      # Get measure record
      my $measure = $rla->{'measures'}->[$i];
      
      # Get measure-word fields
      my $msw_trad = $measure->[0];
      my $msw_simp = $measure->[1];
      my $msw_pny  = undef;
      if (scalar(@$measure) >= 3) {
        $msw_pny = $measure->[2];
      }
      
      # Get a reference for this measure word
      my $msw_refid = enter_ref($dbc, $msw_trad, $msw_simp, $msw_pny);
      
      # Add the measure word
      $dbh->do(
              'INSERT INTO msm(mpyid, msmord, refid) VALUES (?, ?, ?)',
              undef,
              $mpy_id, $i + 1, $msw_refid);
    }
    
    # Add any record-level alternate pronunciations
    my $apm_count = 0;
    for(my $i = 0; $i < scalar(@{$rla->{'pronun'}}); $i++) {
      # Get pronunciation record
      my $pr = $rla->{'pronun'}->[$i];
      
      # Get scalar pronunciation fields
      my $pr_context   = $pr->[0];
      my $pr_condition = $pr->[2];
      
      # Convert scalar fields into atom values
      $pr_context   = enter_atom($dbc, $pr_context);
      $pr_condition = enter_atom($dbc, $pr_condition);
      
      # Add each of the Pinyin in this record
      for my $pny (@{$pr->[1]}) {
        # Increase apm record count
        $apm_count++;
        
        # Add record
        $dbh->do(
                'INSERT INTO '
                . 'apm(mpyid, apmord, apmctx, apmcond, apmpny) '
                . 'VALUES (?, ?, ?, ?, ?)',
                undef,
                $mpy_id,
                $apm_count,
                $pr_context,
                $pr_condition,
                string_to_db($pny));
      }
    }
    
    # Add any record-level cross-references
    my $xrm_count = 0;
    for(my $i = 0; $i < scalar(@{$rla->{'xref'}}); $i++) {
      # Get cross-reference record
      my $xref = $rla->{'xref'}->[$i];
      
      # Get scalar cross-reference fields
      my $xr_description = $xref->[0];
      my $xr_type        = $xref->[1];
      my $xr_suffix      = $xref->[3];
      
      # Convert scalar fields into atom values
      $xr_description = enter_atom($dbc, $xr_description);
      $xr_type        = enter_atom($dbc, $xr_type);
      $xr_suffix      = enter_atom($dbc, $xr_suffix);
      
      # Add each of the references in this record
      for my $xrr (@{$xref->[2]}) {
        # Increase the xrm record count
        $xrm_count++;
        
        # Get reference fields
        my $xrr_trad = $xrr->[0];
        my $xrr_simp = $xrr->[1];
        my $xrr_pny  = undef;
        if (scalar(@$xrr) >= 3) {
          $xrr_pny = $xrr->[2];
        }
        
        # Get a ref_id for the reference
        my $refid_xrm = enter_ref($dbc, $xrr_trad, $xrr_simp, $xrr_pny);
        
        # Add record
        $dbh->do(
                'INSERT INTO '
                . 'xrm(mpyid, xrmord, refid, xrmdesc, xrmtype, xrmsuf) '
                . 'VALUES (?, ?, ?, ?, ?, ?)',
                undef,
                $mpy_id,
                $xrm_count,
                $refid_xrm,
                $xr_description,
                $xr_type,
                $xr_suffix);
      }
    }
    
    # We've now added all record-level annotations, so it's time to add
    # the glosses and gloss-specific annotations
    my $gloss_ord = 0;
    for my $entry (@{$dict->entries}) {
      # Increment gloss_ord to get current value for this entry
      $gloss_ord++;
      
      # Get a dfn_id for this new gloss, which is one greater than the
      # largest value currently in the table, or 1 if this is the first
      # gloss
      my $dfn_id = 1;
      $qr = $dbh->selectrow_arrayref(
                'SELECT dfnid FROM dfn ORDER BY dfnid DESC');
      if (ref($qr) eq 'ARRAY') {
        $dfn_id = $qr->[0] + 1;
      }
      
      # Add the gloss record
      $dbh->do(
              'INSERT INTO dfn(dfnid, mpyid, dfnord, dfnsen, dfntext) '
              . 'VALUES (?, ?, ?, ?, ?)',
              undef,
              $dfn_id,
              $mpy_id,
              $gloss_ord,
              $entry->{'sense'},
              string_to_db($entry->{'text'}));
      
      # Add all citations for this gloss
      for my $cite (@{$entry->{'cites'}}) {
        # Get citation fields
        my $starting_index = $cite->[0];
        my $cite_length    = $cite->[1];
        my $cite_trad      = $cite->[2];
        my $cite_simp      = $cite->[3];
        my $cite_pny       = undef;
        if (scalar(@$cite) >= 5) {
          $cite_pny = $cite->[4];
        }
        
        # Get a reference for this citation
        my $cite_ref = enter_ref(
                          $dbc, $cite_trad, $cite_simp, $cite_pny);
        
        # Add the citation record
        $dbh->do(
                'INSERT INTO cit(dfnid, citoff, citlen, refid) '
                . 'VALUES (?, ?, ?, ?)',
                undef,
                $dfn_id,
                $starting_index,
                $cite_length,
                $cite_ref);
      }
      
      # Add any gloss-level measure-word/classifiers
      for(my $i = 0; $i < scalar(@{$entry->{'measures'}}); $i++) {
        # Get measure record
        my $measure = $entry->{'measures'}->[$i];
        
        # Get measure-word fields
        my $msw_trad = $measure->[0];
        my $msw_simp = $measure->[1];
        my $msw_pny  = undef;
        if (scalar(@$measure) >= 3) {
          $msw_pny = $measure->[2];
        }
        
        # Get a reference for this measure word
        my $msw_refid = enter_ref($dbc, $msw_trad, $msw_simp, $msw_pny);
        
        # Add the measure word
        $dbh->do(
                'INSERT INTO msd(dfnid, msdord, refid) '
                . 'VALUES (?, ?, ?)',
                undef,
                $dfn_id, $i + 1, $msw_refid);
      }
      
      # Add any gloss-level alternate pronunciations
      my $apd_count = 0;
      for(my $i = 0; $i < scalar(@{$entry->{'pronun'}}); $i++) {
        # Get pronunciation record
        my $pr = $entry->{'pronun'}->[$i];
        
        # Get scalar pronunciation fields
        my $pr_context   = $pr->[0];
        my $pr_condition = $pr->[2];
        
        # Convert scalar fields into atom values
        $pr_context   = enter_atom($dbc, $pr_context);
        $pr_condition = enter_atom($dbc, $pr_condition);
        
        # Add each of the Pinyin in this record
        for my $pny (@{$pr->[1]}) {
          # Increase apd record count
          $apd_count++;
          
          # Add record
          $dbh->do(
                  'INSERT INTO '
                  . 'apd(dfnid, apdord, apdctx, apdcond, apdpny) '
                  . 'VALUES (?, ?, ?, ?, ?)',
                  undef,
                  $dfn_id,
                  $apd_count,
                  $pr_context,
                  $pr_condition,
                  string_to_db($pny));
        }
      }
      
      # Add any gloss-level cross-references
      my $xrd_count = 0;
      for(my $i = 0; $i < scalar(@{$entry->{'xref'}}); $i++) {
        # Get cross-reference record
        my $xref = $entry->{'xref'}->[$i];
        
        # Get scalar cross-reference fields
        my $xr_description = $xref->[0];
        my $xr_type        = $xref->[1];
        my $xr_suffix      = $xref->[3];
        
        # Convert scalar fields into atom values
        $xr_description = enter_atom($dbc, $xr_description);
        $xr_type        = enter_atom($dbc, $xr_type);
        $xr_suffix      = enter_atom($dbc, $xr_suffix);
        
        # Add each of the references in this record
        for my $xrr (@{$xref->[2]}) {
          # Increase the xrd record count
          $xrd_count++;
          
          # Get reference fields
          my $xrr_trad = $xrr->[0];
          my $xrr_simp = $xrr->[1];
          my $xrr_pny  = undef;
          if (scalar(@$xrr) >= 3) {
            $xrr_pny = $xrr->[2];
          }
          
          # Get a ref_id for the reference
          my $refid_xrd = enter_ref(
                            $dbc, $xrr_trad, $xrr_simp, $xrr_pny);
          
          # Add record
          $dbh->do(
                  'INSERT INTO '
                  . 'xrd'
                  . '(dfnid, xrdord, refid, xrddesc, xrdtype, xrdsuf) '
                  . 'VALUES (?, ?, ?, ?, ?, ?)',
                  undef,
                  $dfn_id,
                  $xrd_count,
                  $refid_xrd,
                  $xr_description,
                  $xr_type,
                  $xr_suffix);
        }
      }
    }
  }
  
  # Report progress counter of pass
  printf { \*STDERR } "Added %d records in pass %d.\n",
              $pass_progress, $pass + 1;
  
  # Add pass_progress counter to pass results
  push @pass_results, ($pass_progress);
}

# If we got here, commit all our changes as a single transaction
#
$dbc->finishWork;

# Print out statistics
#
my $total_recs = 0;
for(my $pi = 0; $pi <= $#pass_results; $pi++) {
  $total_recs = $total_recs + $pass_results[$pi];
  printf "Pass %d: Added %d, Cumulative %d\n",
            $pi + 1, $pass_results[$pi], $total_recs;
}

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
