#!/usr/bin/env perl
use strict;
use warnings;

# Sino imports
use Sino::DB;
use Sino::Dict;
use Sino::Op qw(db_to_string);
use SinoConfig;

=head1 NAME

xrefwords.pl - Generate a list of extra words that should be added to
the database so that references can resolve.

=head1 SYNOPSIS

  ./xrefwords.pl

=head1 DESCRIPTION

The script defines four word hashes:  the I<done hash>, the I<extra
hash>, the I<next hash>, and the I<current hash>.  Each hash maps
traditional Han renderings to an integer value of one, such that they
behave like sets of Han readings.

At the start of the script, all traditional Han readings found in the
C<han> table and all traditional Han readings found in the C<mpy> table
are added to the current hash, and the other three hashes are left
empty.

The script then continues making passes through CC-CEDICT until the
current hash is empty.

In each pass through CC-CEDICT, the script only examines records that
have a traditional Han reading that is in the current hash.  For each of
these records, a I<reference list> is generated as the set of all unique
traditional Han readings found within citations for all of the glosses,
and also found within measure-word and cross-reference annotations on
both the record level and the gloss level.  For each Han reading in the
reference list, check whether it is in the done hash or the current
hash.  Any traditional Han readings that are not in either of those
hashes are added to the extra hash and the next hash.  At the end of the
pass, all words in the current hash are moved to the done hash, the next
hash becomes the new current hash, and the next hash is then replaced
with an empty hash.

At the end of all the passes, the next hash and current hashes will both
be empty.  The extra hash will contain all new words that are referenced
indirectly from current records within the database.  Before the final
report, one last pass is made through the dictionary.  This time, all
headwords in the extra hash that have an entry in the dictionary have
their value changed to 2.  Output then only includes headwords from the
extra hash where the value is 2, printed to standard output, one per
line.  All of the reported extra words are then known to be in the
CC-CEDICT dictionary somewhere.

Progress reports regarding passes are printed to standard error.

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

=cut

# ==================
# Program entrypoint
# ==================

# Switch output to UTF-8
#
binmode(STDOUT, ":encoding(UTF-8)") or
  die "Failed to set UTF-8 output, stopped";

# Check that no program arguments
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Define the hashes as references
#
my $rdone    = { };
my $rextra   = { };
my $rnext    = { };
my $rcurrent = { };

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read transaction for reading all the traditional Han
# headwords to put in the current hash
#
my $dbh = $dbc->beginWork('r');

# Prepare a statement to iterate through all Han headwords in the han
# table
#
my $sth = $dbh->prepare('SELECT hantrad FROM han');

# Add all headwords in the han table
#
$sth->execute;
for(my $rec = $sth->fetchrow_arrayref;
    ref($rec) eq 'ARRAY';
    $rec = $sth->fetchrow_arrayref) {
  
  my $htrad = db_to_string($rec->[0]);
  $rcurrent->{$htrad} = 1;
}

# Prepare a statement to iterate through all traditional Han headwords
# in the mpy table
#
$sth = $dbh->prepare(
              'SELECT reftrad FROM mpy '
              . 'INNER JOIN ref ON ref.refid=mpy.refid');

# Add all traditional headwords in the mpy table
#
$sth->execute;
for(my $rec = $sth->fetchrow_arrayref;
    ref($rec) eq 'ARRAY';
    $rec = $sth->fetchrow_arrayref) {
  
  my $htrad = db_to_string($rec->[0]);
  $rcurrent->{$htrad} = 1;
}

# If we got here, commit the transaction
#
$dbc->finishWork;

# Open the dictionary file
#
my $dict = Sino::Dict->load($config_dictpath, $config_datasets);

# Keep performing passes until the current hash is empty
#
my $pass_count = 0;
while (scalar(%$rcurrent) > 0) {
  # Progress report
  $pass_count++;
  my $report = sprintf("Starting pass %d... (%d headwords)\n",
                          $pass_count, scalar(%$rcurrent));
  print {\*STDERR} $report;
  
  # Rewind dictionary
  $dict->rewind;
  
  # Go through all dictionary entries
  while ($dict->advance) {
    # Only process dictionary record if in current hash
    if (defined $rcurrent->{$dict->traditional}) {
      
      # Build the reference-list hash
      my %rlh;
      my $rla = $dict->main_annote;
      
      for my $measure (@{$rla->{'measures'}}) {
        $rlh{$measure->[0]} = 1;
      }
      
      for my $xref (@{$rla->{'xref'}}) {
        for my $xrr (@{$xref->[2]}) {
          $rlh{$xrr->[0]} = 1;
        }
      }
      
      for my $entry (@{$dict->entries}) {
        for my $cite (@{$entry->{'cites'}}) {
          $rlh{$cite->[2]} = 1;
        }
        
        for my $measure (@{$entry->{'measures'}}) {
          $rlh{$measure->[0]} = 1;
        }
        
        for my $xref (@{$entry->{'xref'}}) {
          for my $xrr (@{$xref->[2]}) {
            $rlh{$xrr->[0]} = 1;
          }
        }
      }
      
      # Go through all references we found
      for my $xref_trad (keys %rlh) {
        # Unless this traditional cross-reference is already in either
        # the done hash or the current hash, add it to both the extra
        # hash and the next hash
        unless ((defined $rdone->{$xref_trad}) or
                  (defined $rcurrent->{$xref_trad})) {
          $rextra->{$xref_trad} = 1;
          $rnext->{$xref_trad} = 1;
        }
      }
    }
  }
  
  # Move all headwords in the current hash to the done hash
  for my $hword (keys %$rcurrent) {
    $rdone->{$hword} = 1;
  }
  
  # Move next hash to current hash and set an empty hash as the new next
  # hash
  $rcurrent = $rnext;
  $rnext = { };
}

# If at least one word in the extra hash, make one last pass through the
# dictionary to mark all words in the extra hash that exist in the
# dictionary somewhere with value 2
#
if (scalar(%$rextra) > 0) {
  print {\*STDERR} "Starting clean-up pass...\n";
  $dict->rewind;
  while ($dict->advance) {
    if (defined $rextra->{$dict->traditional}) {
      $rextra->{$dict->traditional} = 2;
    }
  }
}

# Finally, report all the headwords in the extra hash where the value is
# 2
#
for my $hword (sort keys %$rextra) {
  if ($rextra->{$hword} == 2) {
    print "$hword\n";
  }
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
