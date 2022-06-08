#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(decode);

# Sino imports
use Sino::DB;
use SinoConfig;

=head1 NAME

scanpny.pl - Report all Pinyin in the pny table that include certain
ambiguous consonants.

=head1 SYNOPSIS

  ./scanpny.pl -ng
  ./scanpny.pl -r
  ./scanpny.pl -n

=head1 DESCRIPTION

This script goes through all records in the pny table.  For any Pinyin
rendering that includes certain ambiguous consonants (see below), the
word IDs of these Pinyin are reported so that they can be examined.

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

For the C<-ng> option, match any Pinyin that includes the consonant
sequence C<ng> followed by a vowel.

For the C<-r> option, match any Pinyin that includes the consonant C<r>
anywhere.

For the C<-n> option, match any Pinyin that includes the consonant C<n>
surrounded by vowels.

=cut

# ==================
# Program entrypoint
# ==================

# Check that exactly one program argument
#
($#ARGV == 0) or die "Wrong number of program arguments, stopped";

# Get program mode
#
my $program_mode;
if ($ARGV[0] eq '-ng') {
  $program_mode = 'ng';

} elsif ($ARGV[0] eq '-r') {
  $program_mode = 'r';
  
} elsif ($ARGV[0] eq '-n') {
  $program_mode = 'n';
  
} else {
  die "Unrecognized program mode '$program_mode', stopped";
}

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read transaction for everything
#
my $dbh = $dbc->beginWork('r');

# Iterate through all Pinyin renderings in the pny table, building a
# hash that maps matching word IDs to values of 1.
#
my %match_hash;
my $sth = $dbh->prepare(
            'SELECT wordid, pnytext '
            . 'FROM pny '
            . 'INNER JOIN han ON han.hanid = pny.hanid');

$sth->execute;
for(my $row = $sth->fetchrow_arrayref;
    ref($row) eq 'ARRAY';
    $row = $sth->fetchrow_arrayref) {
  
  # Get word ID and decoded Pinyin
  my $word_id = $row->[0];
  my $pinyin  = decode('UTF-8', $row->[1],
                      Encode::FB_CROAK | Encode::LEAVE_SRC);
  
  # Determine whether to add to match hash based on chosen rule
  my $is_match = 0;
  if ($program_mode eq 'ng') {
    if ($pinyin =~ /ng[^b-df-hj-np-tv-z]/i) {
      $is_match = 1;
    }
    
  } elsif ($program_mode eq 'r') {
    if ($pinyin =~ /r/i) {
      $is_match = 1;
    }
    
  } elsif ($program_mode eq 'n') {
    if ($pinyin =~ /[^b-df-hj-np-tv-z]n[^b-df-hj-np-tv-z]/i) {
      $is_match = 1;
    }
    
  } else {
    die "Unexpected";
  }
  
  # Add to match hash if we got a match
  if ($is_match) {
    $match_hash{"$word_id"} = 1;
  }
}

# If we got here, commit the transaction
#
$dbc->finishWork;

# Print a sorted list of all (unique) word IDs
#
for my $word_id (sort { int($a) <=> int($b) } keys %match_hash) {
  print "$word_id\n";
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
