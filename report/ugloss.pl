#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(decode);

# Sino imports
use Sino::DB;
use Sino::Util qw(
                parse_measures
                extract_pronunciation
                extract_xref);
use SinoConfig;

=head1 NAME

ugloss.pl - Report all glosses that contain Unicode beyond ASCII range
or square brackets, and the words they belong to.

=head1 SYNOPSIS

  ./ugloss.pl
  ./ugloss.pl -nocl
  ./ugloss.pl -nopk
  ./ugloss.pl -noxref
  ./ugloss.pl -wordid

=head1 DESCRIPTION

This script reads through all glosses.  Any gloss that contains any
character outside the range [U+0020, U+007E], and any gloss that
contains ASCII square brackets, is printed to output, along with the
word ID the gloss belongs to.

The C<-nocl> option ignores any gloss that matches a classifier gloss,
as determined by the C<parse_measures> function of C<Sino::Util>.

The C<-nopk> option uses the C<extract_pronunciation> function of
C<Sino::Util> on glosses before they are examined, so that alternate
pronunciations won't be included in the reported list.

The C<-noxref> option uses the C<extract_xref> function of C<Sino::Util>
on glosses before they are examined, so that cross-references won't be
included in the reported list.

The C<-wordid> causes only a list of word IDs to be reported, rather
than glosses with word IDs.

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

# Parse options
#
my $flag_nocl   = 0;
my $flag_nopk   = 0;
my $flag_noxref = 0;
my $flag_wordid = 0;

for(my $i = 0; $i <= $#ARGV; $i++) {
  if ($ARGV[$i] eq '-nocl') {
    $flag_nocl = 1;
  
  } elsif ($ARGV[$i] eq '-nopk') {
    $flag_nopk = 1;
  
  } elsif ($ARGV[$i] eq '-noxref') {
    $flag_noxref = 1;
  
  } elsif ($ARGV[$i] eq '-wordid') {
    $flag_wordid = 1;
    
  } else {
    die "Unrecognized option '$ARGV[$i]', stopped";
  }
}

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read transaction for everything
#
my $dbh = $dbc->beginWork('r');

# Prepare a statement to iterate through all glosses along with the
# word IDs they belong to
#
my $sth = $dbh->prepare(
            'SELECT wordid, dfntext '
            . 'FROM dfn '
            . 'INNER JOIN mpy ON mpy.mpyid = dfn.mpyid '
            . 'INNER JOIN han ON han.hanid = mpy.hanid');

# Go through all glosses
#
$sth->execute;
my %id_hash;
for(my $rec = $sth->fetchrow_arrayref;
    ref($rec) eq 'ARRAY';
    $rec = $sth->fetchrow_arrayref) {
  
  # Get the gloss and word ID
  my $word_id = $rec->[0];
  my $gloss   = decode('UTF-8', $rec->[1],
                        Encode::FB_CROAK | Encode::LEAVE_SRC);
  
  # If -nopk mode, then attempt to extract pronunciation and replace
  # gloss with altered gloss
  if ($flag_nopk) {
    my $retval = extract_pronunciation($gloss);
    if (defined $retval) {
      $gloss = $retval->[0];
    }
  }
  
  # If -noxref mode, then attempt to extract cross-reference and replace
  # gloss with altered gloss
  if ($flag_noxref) {
    my $retval = extract_xref($gloss);
    if (defined $retval) {
      $gloss = $retval->[0];
    }
  }
  
  # Report if gloss contains anything outside of US-ASCII printing range
  unless ($gloss =~ /\A[\x{20}-\x{5a}\x{5c}\x{5e}-\x{7e}]*\z/) {
    # Start print_request at 1
    my $print_request = 1;
    
    # If in -nocl mode, skip glosses that match measure words
    if ($flag_nocl) {
      if (defined(parse_measures($gloss))) {
        $print_request = 0;
      }
    }
    
    # Print if requested
    if ($print_request) {
      if ($flag_wordid) {
        if (not defined $id_hash{"$word_id"}) {
          print "$word_id\n";
          $id_hash{"$word_id"} = 1;
        }
      } else {
        print "$word_id: $gloss\n";
      }
    }
  }
}

# If we got here, commit the transaction
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
