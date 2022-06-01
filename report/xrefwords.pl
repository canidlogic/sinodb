#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(decode);

# Sino imports
use Sino::DB;
use Sino::Dict;
use Sino::Util qw(extract_xref);
use SinoConfig;

=head1 NAME

xrefwords.pl - Generate a list of extra words that should be added to
the database so that all cross-references can resolve.

=head1 SYNOPSIS

  ./xrefwords.pl

=head1 DESCRIPTION

The script defines four word hashes:  the I<done hash>, the <extra
hash>, the I<next hash>, and the I<current hash>.  Each hash maps
traditional Han renderings to an integer value of one, such that they
behave like sets of Han readings.

At the start of the script, all traditional Han readings found in the
C<han> table and all traditional Han readings found in the C<mpy> table
are added to the current hash, and the other three hashes are left
empty.

The script then continues making passes through CC-CEDICT until the
current hash is empty.

In each pass through CC-CEDICT, the script only examines glosses that
have a traditional Han reading that is in the current hash.  The
C<extract_xref> is used on each of these glosses to check whether there
are any cross-references.  If there are, then the traditional Han
rendering(s) of each cross-reference is checked whether it is in done
hash or the current hash.  Any traditional Han renderings that are not
in either of those hases are added to the extra hash and the next hash.
At the end of the pass, all words in the current hash are moved to the
done hash, the next hash becomes the new current hash, and the next hash
is then replaced with an empty hash.

At the end of all the passes, the next hash and current hashes will both
be empty.  The extra hash will contain all words that should be added to
the database so that all cross-references can resolve.  Before the final
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
  
  my $htrad = decode('UTF-8', $rec->[0],
                      Encode::FB_CROAK | Encode::LEAVE_SRC);
  $rcurrent->{$htrad} = 1;
}

# Prepare a statement to iterate through all traditional Han headwords
# in the mpy table
#
$sth = $dbh->prepare('SELECT mpytrad FROM mpy');

# Add all traditional headwords in the mpy table
#
$sth->execute;
for(my $rec = $sth->fetchrow_arrayref;
    ref($rec) eq 'ARRAY';
    $rec = $sth->fetchrow_arrayref) {
  
  my $htrad = decode('UTF-8', $rec->[0],
                      Encode::FB_CROAK | Encode::LEAVE_SRC);
  $rcurrent->{$htrad} = 1;
}

# If we got here, commit the transaction
#
$dbc->finishWork;

# Open the dictionary file
#
my $dict = Sino::Dict->load($config_dictpath);

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
  
  # Go through all glosses of all dictionary entries that have
  # traditional headwords in the current hash
  while ($dict->advance) {
    if (defined $rcurrent->{$dict->traditional}) {
      for my $sense ($dict->senses) {
        for my $gloss (@$sense) {
          
          # Try to extract a cross-reference from this gloss
          my $xref = extract_xref($gloss);
          if (defined $xref) {
            # We got a cross-reference, so go through any traditional
            # headwords in the cross-reference
            for my $xr (@{$xref->[3]}) {
              # Get current cross-reference traditional character
              my $xref_trad = $xr->[0];
              
              # Unless this traditional cross-reference is already in
              # either the done hash or the current hash, add it to both
              # the extra hash and the next hash
              unless ((defined $rdone->{$xref_trad}) or
                        (defined $rcurrent->{$xref_trad})) {
                $rextra->{$xref_trad} = 1;
                $rnext->{$xref_trad} = 1;
              }
            }
          }
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
