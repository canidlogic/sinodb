#!/usr/bin/env perl
use strict;
use warnings;

# Dict modules
use Dict::Parse;
use DictConfig;

=head1 NAME

dupscan.pl - Scan through the CC-CEDICT data file and report all groups
of entries that have the same traditional character headword and Pinyin.

=head1 SYNOPSIS

  ./dupscan.pl
  ./dupscan.pl -ci -nt
  ./dupscan.pl -limit 4 -np -uc

=head1 DESCRIPTION

Scans through the CC-CEDICT data file.  Records a mapping of traditional
character strings and Pinyin to all line numbers they are used on.
Then, reports all groups on line numbers with the same keys.

You can pass flags indicating operations to perform on keys before they
are stored.  The following flags are supported:

=over 4

=item C<-ci>

Pinyin will be made lowercase, so that duplication detection is case
insensitive.  Ignored if C<-np> is specified.

=item C<-nt>

Tone numbers will be dropped from Pinyin so that comparisons are done
without consideration for tone.  Ignored if C<-np> is specified.

=item C<-np>

No Pinyin will be considered and duplication detection works on
traditional characters only.

=item c<-nn>

Do not consider records where the Pinyin begins with a capital letter,
indicating a proper name.

=item C<-uc>

Only consider records where all traditional characters are within the
core CJK Unicode block [U+4E00 U+9FFF] I<and> the number of traditional
characters equals the number of Pinyin syllables.

=item C<-limit> I<length>

Given an unsigned integer parameter that is greater than zero, only
consider records where the traditional character rendering does not
exceed the given length.

=back

=cut

# ==================
# Program entrypoint
# ==================

# Get flag values
#
my $flag_ci = 0;
my $flag_nt = 0;
my $flag_np = 0;
my $flag_nn = 0;
my $flag_uc = 0;
my $len_limit = undef;

for(my $i = 0; $i <= $#ARGV; $i++) {
  if ($ARGV[$i] eq '-ci') {
    $flag_ci = 1;
    
  } elsif ($ARGV[$i] eq '-nt') {
    $flag_nt = 1;
  
  } elsif ($ARGV[$i] eq '-np') {
    $flag_np = 1;
    
  } elsif ($ARGV[$i] eq '-nn') {
    $flag_nn = 1;
  
  } elsif ($ARGV[$i] eq '-uc') {
    $flag_uc = 1;
    
  } elsif ($ARGV[$i] eq '-limit') {
    ($i < $#ARGV) or die "-limit needs a parameter, stopped";
    $i++;
    ($ARGV[$i] =~ /\A[1-9][0-9]*\z/) or
      die "Invalid length limit, stopped";
    (not defined $len_limit) or
      die "Can only have one length limit, stopped";
    $len_limit = int($ARGV[$i]);
  
  } else {
    die "Unrecognized flag '$ARGV[$i]', stopped";
  }
}

# Open the parser
#
my $dict = Dict::Parse->load($config_dictpath);

# Build mapping of traditional headwords and Pinyin to line numbers
#
my %tcm;
while ($dict->advance) {
  # Get traditional headword and Pinyin
  my $hword = $dict->traditional;
  my $pny   = join ' ', $dict->pinyin;
  
  # If no-name flag, skip if Pinyin starts with uppercase letter
  if ($flag_nn) {
    (not ($pny =~ /\A[A-Z]/)) or next;
  }
  
  # If length limit defined, skip if headword too long
  if (defined $len_limit) {
    (length($hword) <= $len_limit) or next;
  }
  
  # If usual-character flag, skip unless all traditional characters in
  # core Unicode range and number of traditional characters equals
  # number of Pinyin syllables
  if ($flag_uc) {
    ($hword =~ /\A[\x{4E00}-\x{9FFF}]+\z/) or next;
    (length($hword) == scalar($dict->pinyin)) or next;
  }
  
  # If no-pinyin flag, change pinyin to empty string
  if ($flag_np) {
    $pny = '';
  }
  
  # If case-insensitive flag, covert Pinyin to lowercase
  if ($flag_ci) {
    $pny =~ tr/A-Z/a-z/;
  }
  
  # If no-tones flag, drop tone numbers
  if ($flag_nt) {
    $pny =~ s/([A-Za-z:])[1-5]/$1/g;
  }
  
  # Define key
  my $kval = "$hword $pny";
  
  # Add into mapping
  if (defined $tcm{$kval}) {
    # Already defined, so push line number to end of list
    push @{$tcm{$kval}}, ($dict->line_number);
    
  } else {
    # Not already defined, so start list with this line number
    $tcm{$kval} = [$dict->line_number];
  }
}

# Only interested in cases where more than one record, so drop
# everything else
#
my @del_key;
for my $k (keys %tcm) {
  if (scalar(@{$tcm{$k}}) <= 1) {
    push @del_key, ($k);
  }
}
for my $k (@del_key) {
  delete $tcm{$k};
}
@del_key = ( );

# Report all remaining groups, and count number of groups and total
# number of entries involved in groups
#
my $total_groups  = 0;
my $total_entries = 0;
for my $va (sort { int($a->[0]) <=> int($b->[0]) } values %tcm) {
  $total_groups++;
  my $first = 1;
  for my $r (@$va) {
    if ($first) {
      $first = 0;
    } else {
      print ' ';
    }
    print "$r";
    $total_entries++;
  }
  print "\n";
}

# Report total
#
print "# Total groups : $total_groups\n";
print "# Total entries: $total_entries\n";

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
