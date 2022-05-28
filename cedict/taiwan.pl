#!/usr/bin/env perl
use strict;
use warnings;

# Dict modules
use Dict::Parse;
use DictConfig;

=head1 NAME

taiwan.pl - Scan the dictionary and report unusual cases regarding
Taiwan pronunciation indications.

=head1 SYNOPSIS

  ./taiwan.pl special
  ./taiwan.pl major

=head1 DESCRIPTION

In C<special> mode, this script scans for all Taiwan pronunciation
glosses that don't follow the standard format and reports them.  In
C<major> mode, this script only considers Taiwan pronunciation glosses
that are in the standard format, and reports any situations where the
Taiwan pronunciation differs by more than tone.

=head Special mode

Scans through all glosses in all records in the dictionary.  Any glosses
that contain a case-insensitive match for C<Taiwan pr> or C<Taiwanpr>
are checked whether they are in the standard format:

=over 4

=item *
(Start of gloss)

=item *
C<Taiwan> (case-insensitive)

=item *
Zero or more whitespace characters

=item *
C<pr.> (case-insensitive)

=item *
Zero or more whitespace characters

=item *
Left square bracket C<[>

=item *
Sequence of zero or more characters not including C<[]>

=item *
Right square bracket C<]>

=item *
(End of gloss)

=back

Any glosses that are I<not> in this standard format are printed, along
with their record line numbers.

=head2 Major mode

Scans through all glosses in all records in the dictionary, considering
only glosses that have a Taiwan pronunciation gloss in the standard
format.  Any cases where the Taiwan pronunciation gloss differs from the
main entry Pinyin by more than tone are reported.

=cut

# ==================
# Program entrypoint
# ==================

# Switch output to UTF-8
#
binmode(STDOUT, ":encoding(UTF-8)") or
  die "Failed to set UTF-8 output, stopped";

# Check and get argument
#
($#ARGV == 0) or die "Expecting exactly one program argument, stopped";
my $scan_mode = $ARGV[0];

# Open the parser
#
my $dict = Dict::Parse->load($config_dictpath);

# Handle the modes
#
if ($scan_mode eq 'special') { # =======================================

  # Go through all records
  while ($dict->advance) {
    # Look for Taiwan
    for my $sense ($dict->senses) {
      for my $gloss (@$sense) {
        if ($gloss =~ /Taiwan\s*pr/i) {
          # We found a Taiwan pronuncation gloss, so report it if it is
          # not the standard format
          if (not $gloss =~
                /
                  \A
                  Taiwan
                  \s*
                  pr\.
                  \s*
                  \[
                  [^\[\]]*
                  \]
                  \z
                /xi) {
            my $mainland_pinyin = join ' ', $dict->pinyin;
            printf "%d: [%s] %s\n", 
                  $dict->line_number, $mainland_pinyin, $gloss;
          }
        }
      }
    }
  }
  
} elsif ($scan_mode eq 'major') { # ====================================
  
  # Go through all records
  while ($dict->advance) {
    # Look for glosses in standard Taiwan format
    for my $sense ($dict->senses) {
      for my $gloss (@$sense) {
        if ($gloss =~
              /
                \A
                Taiwan
                \s*
                pr\.
                \s*
                \[
                ([^\[\]]*)
                \]
                \z
              /xi) {
          # We found a standard Taiwan gloss -- get the Pinyin
          my $twp = $1;
          
          # Whitespace-trim Taiwan Pinyin then split into tokens with
          # whitespace separation
          $twp =~ s/\A\s+//;
          $twp =~ s/\s+\z//;
          my @tws = split ' ', $twp;
          
          # Get the Taiwan string with whitespace normalized and the
          # main Pinyin string with whitespace normalized
          my $taiwan_pinyin   = join ' ', @tws;
          my $mainland_pinyin = join ' ', $dict->pinyin;
          
          # Drop decimal digits from both for tone-less rendering
          my $taiwan_toneless   = $taiwan_pinyin;
          my $mainland_toneless = $mainland_pinyin;
          
          $taiwan_toneless   =~ s/[1-9]//g;
          $mainland_toneless =~ s/[1-9]//g;
          
          # Only report if toneless renderings are different
          unless ($taiwan_toneless eq $mainland_toneless) {
            my $dfn = '';
            for my $sn ($dict->senses) {
              $dfn = $dfn . '/';
              my $first_gloss = 1;
              for my $gls (@$sn) {
                if ($first_gloss) {
                  $first_gloss = 0;
                } else {
                  $dfn = $dfn . '; ';
                }
                $dfn = $dfn . $gls;
              }
            }
            $dfn = $dfn . '/';
            printf "%d: [%s] [%s] %s\n",
                    $dict->line_number,
                    $mainland_pinyin,
                    $taiwan_pinyin,
                    $dfn;
          }
        }
      }
    }
  }
  
} else { # =============================================================
  die "Unrecognized scan mode '$scan_mode', stopped";
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
