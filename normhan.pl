#!/usr/bin/env perl
use strict;
use warnings;

# Sino imports
use Sino::DB;
use Sino::Op qw(
                string_to_db
                db_to_string);
use SinoConfig;

=head1 NAME

normhan.pl - Build the normalized Han lookup tables of the database.

=head1 SYNOPSIS

  ./normhan.pl

=head1 DESCRIPTION

This script is used to build the smp and spk normalized Han lookup
tables within the Sino database, which allow for Han headword queries
according to I<normalized Han>.  Normalized Han is not part of the
Unicode standard, as is instead defined specifically by Sino as a way of
querying for headwords independent of whether characters are given in
simplified or traditional form.  See C<createdb.pl> for a formal
definition of normalized Han.

This script should be run after you have imported all the glosses into
the C<dfn> table using C<import_cedict.pl>.  The C<smp> table must be
empty when you start running this script.

The first step of this script is to go through the C<ref> table and
build a hash mapping each codepoint to codepoints that are connected to
it, but excluding trivial connections of codepoints to themselves and
not including codepoints that lack any connections except to themselves.

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

=cut

# ==========
# Local data
# ==========

# Hash mapping codepoint integers to arrays of codepoint integers that
# they are connected to (excluding self connections)
#
my %chash;

# Hash mapping codepoint integers to their normal form.
#
my %nhash;

# ===============
# Local functions
# ===============

# find_least($cpv, \%visited, $least)
#
# Recursively find the minimum codepoint value that a given codepoint is
# connected to either directly or indirectly through %chash.
#
# $cpv is the codepoint value that we want to begin the search at.
# \%visited is a reference to a hash that maps all codepoints that have
# been recursively examined to a value of 1.  $least is the lowest
# connected codepoint value that has been found so far.
#
# To begin with, set $cpv and $least to the same value, being the
# codepoint value you want to find the minimum for.  Also, set \%visited
# to an empty hash reference {} indicating that no nodes have been
# visited yet.
#
sub find_least {
  # Get parameters
  ($#_ == 2) or die "Wrong number of parameters, stopped";
  
  my $cpv = shift;
  (not ref($cpv)) or die "Invalid parameter type, stopped";
  
  (int($cpv) == $cpv) or die "Invalid parameter type, stopped";
  $cpv = int($cpv);
  
  (($cpv >= 0x4e00) and ($cpv <= 0x9fff)) or
    die "Han codepoint out of range, stopped";
  
  my $visited = shift;
  (ref($visited) eq 'HASH') or die "Invalid parameter type, stopped";
  
  my $least = shift;
  (not ref($least)) or die "Invalid parameter type, stopped";
  
  (int($least) == $least) or die "Invalid parameter type, stopped";
  $least = int($least);
  
  (($least >= 0x4e00) and ($least <= 0x9fff)) or
    die "Han codepoint out of range, stopped";
  
  # If this codepoint value is less than the least value, update the
  # least value to this codepoint value
  if ($cpv < $least) {
    $least = $cpv;
  }
  
  # If this codepoint already in the visited hash, then just return the
  # current least value
  if (defined $visited->{"$cpv"}) {
    return $least;
  }
  
  # Add this codepoint to the visited hash
  $visited->{"$cpv"} = 1;
  
  # Recursively find least value from all connected nodes and update the
  # least value
  for my $search (@{$chash{"$cpv"}}) {
    my $retval = find_least($search, $visited, $least);
    if ($retval < $least) {
      $least = $retval;
    }
  }
  
  # Return result
  return $least;
}

# set_norm($cpv, \%visited, $norm)
#
# Recursively set the given codepoint value and all connected codepoint
# values (both directly and indirectly) to the given normalized value
# norm in %nhash by following the connections in %chash.
#
# $cpv is the codepoint value that we want to begin the set operation
# at.  \%visited is a reference to a hash that maps all codepoints that
# have been recursively visited during this operation to a value of 1.
# $norm is the normal value to set all the discovered nodes to.
#
# None of the discovered nodes may already be in the %nhash yet.
#
sub set_norm {
  # Get parameters
  ($#_ == 2) or die "Wrong number of parameters, stopped";
  
  my $cpv = shift;
  (not ref($cpv)) or die "Invalid parameter type, stopped";
  
  (int($cpv) == $cpv) or die "Invalid parameter type, stopped";
  $cpv = int($cpv);
  
  (($cpv >= 0x4e00) and ($cpv <= 0x9fff)) or
    die "Han codepoint out of range, stopped";
  
  my $visited = shift;
  (ref($visited) eq 'HASH') or die "Invalid parameter type, stopped";
  
  my $norm = shift;
  (not ref($norm)) or die "Invalid parameter type, stopped";
  
  (int($norm) == $norm) or die "Invalid parameter type, stopped";
  $norm = int($norm);
  
  (($norm >= 0x4e00) and ($norm <= 0x9fff)) or
    die "Han codepoint out of range, stopped";
  
  # If this codepoint already in the visited hash, then do nothing
  # further
  if (defined $visited->{"$cpv"}) {
    return;
  }
  
  # Add this codepoint to the visited hash
  $visited->{"$cpv"} = 1;
  
  # Make sure not already in nhash, then add it
  (not defined $nhash{"$cpv"}) or
    die "Normal form already defined, stopped";
  $nhash{"$cpv"} = $norm;
  
  # Recursively set normal value in all connected nodes
  for my $search (@{$chash{"$cpv"}}) {
    set_norm($search, $visited, $norm);
  }
}

# ==================
# Program entrypoint
# ==================

# Set UTF-8 diagnostics
#
binmode(STDERR, ':encoding(UTF-8)') or
  die "Failed to set UTF-8 diagnostics, stopped";

# Check that there are no program arguments
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read-write transaction for everything
#
my $dbh = $dbc->beginWork('rw');

# Make sure there are no normal groups yet
#
my $qr = $dbh->selectrow_arrayref('SELECT smpid FROM smp');
(not (ref($qr) eq 'ARRAY')) or
  die "Han normalizations already present, stopped";

# Go through the ref table and build the connections hash
#
my $sth = $dbh->prepare(
            'SELECT DISTINCT reftrad, refsimp '
            . 'FROM ref '
            . 'WHERE reftrad <> refsimp');

$sth->execute;
for(my $row = $sth->fetchrow_arrayref;
    defined $row;
    $row = $sth->fetchrow_arrayref) {
  
  # We got a row where traditional and simplified are not exactly the
  # same; fetch the row values
  my $trad = db_to_string($row->[0]);
  my $simp = db_to_string($row->[1]);
  
  # Ignore record if length in codepoints of both does not match
  (length($trad) == length($simp)) or next;
  
  # Go through the traditional and simplified comparing corresponding
  # codepoints and add any differences to the chash
  my @trada = split //, $trad;
  my @simpa = split //, $simp;
  
  for(my $i = 0; $i <= $#trada; $i++) {
    if ($trada[$i] ne $simpa[$i]) {
      # Get the codepoints of the traditional/simplified correspondence
      my $cpv1 = ord($trada[$i]);
      my $cpv2 = ord($simpa[$i]);
      
      # Make sure hash entries for both keys are defined
      unless (defined $chash{"$cpv1"}) {
        $chash{"$cpv1"} = [];
      }
      unless (defined $chash{"$cpv2"}) {
        $chash{"$cpv2"} = [];
      }
      
      # Insert connections into hash if they don't already exist
      for(my $j = 0; $j < 2; $j++) {
        # Get current source and target
        my $src;
        my $target;
        
        if ($j == 0) {
          $src    = $cpv1;
          $target = $cpv2;
        
        } elsif ($j == 1) {
          $src    = $cpv2;
          $target = $cpv1;
        
        } else {
          die "Unexpected";
        }
        
        # Check whether source to target mapping is defined yet
        my $is_defined = 0;
        for my $r (@{$chash{"$src"}}) {
          if ($r == $target) {
            $is_defined = 1;
            last;
          }
        }
        
        # If source to target mapping not defined, add it
        unless ($is_defined) {
          push @{$chash{"$src"}}, ($target);
        }
      }
    }
  }
}

# Compute the normal form hash
#
for my $key (keys %chash) {
  # If this key has already been computed in the normal hash, skip it
  (not defined $nhash{$key}) or next;
  
  # Recursively find the least codepoint value this key is connected to
  # either directly or indirectly
  my $least = find_least(int($key), {}, int($key));
  
  # Recursively set the normal value to all nodes in this network
  set_norm(int($key), {}, $least);
}

# Add all normalization records into smp table
#
for my $key (sort { int($a) <=> int($b) } keys %nhash) {
  # Get the codepoint value and its normalized codepoint value
  my $cpv  = int($key);
  my $norm = $nhash{$key};
  
  # Add this record into the smp table
  $dbh->do(
            'INSERT INTO smp(smpsrc, smpnorm) VALUES (?, ?)',
            undef,
            $cpv, $norm);
}

# Get all the records in the han table mapping word IDs to their
# traditional readings
#
$qr = $dbh->selectall_arrayref(
            'SELECT wordid, hantrad '
            . 'FROM han '
            . 'ORDER BY wordid ASC, hanord ASC');
((ref($qr) eq 'ARRAY') and (scalar(@$qr) > 0)) or
  die "No Han reading records, stopped";

# Fill the spk table with normalized Han index records
#
for my $rec (@$qr) {
  # Get the fields of this record
  my $wordid  = $rec->[0];
  my $hantrad = db_to_string($rec->[1]);
  
  # Get a normalized version of the Han reading
  my $hana = '';
  for my $c (split //, $hantrad) {
    # Get current codepoint value
    my $cpv = ord($c);
    
    # If there is a normalized form, replace the codepoint value
    if (defined ($nhash{"$cpv"})) {
      $cpv = $nhash{"$cpv"};
    }
    
    # Add the normalized codepoint to the string
    $hana = $hana . chr($cpv);
  }
  
  # Add the normalized index record if it doesn't already exist in the
  # lookup table
  $qr = $dbh->selectrow_arrayref(
                'SELECT spkid FROM spk WHERE wordid=? AND spknorm=?',
                undef,
                $wordid, string_to_db($hana));
  unless (ref($qr) eq 'ARRAY') {
    $dbh->do(
          'INSERT INTO spk(wordid, spknorm) VALUES (?, ?)',
          undef,
          $wordid, string_to_db($hana));
  }
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
