#!/usr/bin/env perl
use strict;
use warnings;

# Core dependencies
use Encode qw(encode);

# Sino imports
use Sino::DB;
use Sino::Util qw(han_exmap pinyin_count han_count);
use SinoConfig;

=head1 NAME

import_tocfl.pl - Import data from TOCFL into the Sino database.

=head1 SYNOPSIS

  ./import_tocfl.pl

=head1 DESCRIPTION

This script is used to fill a Sino database with information derived
from TOCFL vocabulary data files.  This script should be your second
step after using C<createdb.pl> to create an empty Sino database.

See C<config.md> in the C<doc> directory for configuration you must do
before using this script.

Note that the database has the requirement that no two words have the
same Han reading, but there are indeed cases in the TOCFL data where two
different entries have the same Han reading.  When this situation
happens, this script will merge the two entries together into a single
word.  The merger process is explained in further detail in the table
documentation for C<createdb.pl>

This script will also handle cleaning up the input data and fixing some
typos (such as tonal diacritics in Pinyin being placed on the wrong
vowel, or some missing Pinyin readings for abbreviated forms).  It will
also intelligently use C<han_exmap>, C<pinyin_count>, and C<han_count>
from C<Sino::Util> to properly map Pinyin readings to Han character
readings, even though this isn't explicit in the TOCFL datasets.

=cut

# ===============
# Local functions
# ===============

# pny_addifnew(dbc, hanid, pny)
#
# Given a Sino::DB database connection, a hanid, and Pinyin text, add it
# as a Pinyin reading of the given hanid unless it is already present in
# the pny table.
#
# This function does not check that the given hanid actually exists in
# the han table, and it does not check that pny is valid Pinyin.
#
sub pny_addifnew {
  # Get and check parameters
  ($#_ == 2) or die "Wrong parameter count, stopped";
  
  my $dbc = shift;
  (ref($dbc) and $dbc->isa('Sino::DB')) or
    die "Wrong parameter type, stopped";
  
  my $hanid = shift;
  my $pny   = shift;
  
  ((not ref($hanid)) and (not ref($pny))) or
    die "Wrong parameter type, stopped";
  
  (int($hanid) == $hanid) or
    die "Wrong parameter type, stopped";
  $hanid = int($hanid);
  ($hanid >= 0) or die "Parameter out of range, stopped";
  
  # Encode Pinyin in binary, in-place OK
  $pny = encode('UTF-8', $pny, Encode::FB_CROAK);
  
  # Start a read/write work block
  my $dbh = $dbc->beginWork('rw');
  
  # Find whether the given Pinyin already exists for this word
  my $qr = $dbh->selectrow_arrayref(
                'SELECT pnyid FROM pny WHERE hanid=? AND pnytext=?',
                undef,
                $hanid, $pny);
  
  # Proceed if we didn't find anything yet
  unless (ref($qr) eq 'ARRAY') {
    # Get the next ord for this hanid in the pny table, or 1 if no 
    # records yet
    my $pny_ord = $dbh->selectrow_arrayref(
                    'SELECT pnyord FROM pny WHERE hanid=? '
                    . 'ORDER BY pnyord DESC',
                    undef,
                    $hanid);
    if (ref($pny_ord) eq 'ARRAY') {
      $pny_ord = $pny_ord->[0] + 1;
    } else {
      $pny_ord = 1;
    }
    
    # Insert into table
    $dbh->do(
        'INSERT INTO pny(hanid, pnyord, pnytext) VALUES (?,?,?)',
        undef,
        $hanid, $pny_ord, $pny);
  }
  
  # Finish the work block if we got here
  $dbc->finishWork;
}

# wc_addifnew(dbc, wordid, wclassid)
#
# Given a Sino::DB database connection, a wordid, and a word class ID,
# add it as a word class of the given wordid unless it is already
# present in the han table.
#
# This function does not check that the given wordid actually exists in
# the word table, and it does not check that wclassid actually is a
# valid foreign key.
#
sub wc_addifnew {
  # Get and check parameters
  ($#_ == 2) or die "Wrong parameter count, stopped";
  
  my $dbc = shift;
  (ref($dbc) and $dbc->isa('Sino::DB')) or
    die "Wrong parameter type, stopped";
  
  my $wordid   = shift;
  my $wclassid = shift;
  
  ((not ref($wordid)) and (not ref($wclassid))) or
    die "Wrong parameter type, stopped";
  
  (int($wordid) == $wordid) or
    die "Wrong parameter type, stopped";
  $wordid = int($wordid);
  ($wordid >= 0) or die "Parameter out of range, stopped";
  
  (int($wclassid) == $wclassid) or
    die "Wrong parameter type, stopped";
  $wclassid = int($wclassid);
  ($wclassid >= 0) or die "Parameter out of range, stopped";
  
  # Start a read/write work block
  my $dbh = $dbc->beginWork('rw');
  
  # Find whether the given word class already exists for this word
  my $qr = $dbh->selectrow_arrayref(
                'SELECT wcid FROM wc WHERE wordid=? AND wclassid=?',
                undef,
                $wordid, $wclassid);
  
  # Proceed if we didn't find anything yet
  unless (ref($qr) eq 'ARRAY') {
    # Get the next ord for this wordid in the wc table, or 1 if no
    # records yet
    my $wc_ord = $dbh->selectrow_arrayref(
                    'SELECT wcord FROM wc WHERE wordid=? '
                    . 'ORDER BY wcord DESC',
                    undef,
                    $wordid);
    if (ref($wc_ord) eq 'ARRAY') {
      $wc_ord = $wc_ord->[0] + 1;
    } else {
      $wc_ord = 1;
    }
    
    # Insert into table
    $dbh->do(
        'INSERT INTO wc(wordid, wcord, wclassid) VALUES (?,?,?)',
        undef,
        $wordid, $wc_ord, $wclassid);
  }
  
  # Finish the work block if we got here
  $dbc->finishWork;
}

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

# pinyin_fix(\@pnys, \@hws)
#
# Apply any corrections for typos etc. in a Pinyin array read from the
# TOCFL data sources.  The given headword array is never modified.
#
sub pinyin_fix {
  # Get and check parameters
  ($#_ == 1) or die "Wrong parameter count, stopped";
  my $aa = shift;
  my $bb = shift;
  (ref($aa) eq 'ARRAY') or die "Wrong parameter type, stopped";
  (ref($bb) eq 'ARRAY') or die "Wrong parameter type, stopped";
  
  # Correct typos
  for my $str (@$aa) {
    if ($str eq "pi\x{e0}ol\x{ec}ang") {
      $str = "pi\x{e0}oli\x{e0}ng";
    
    } elsif ($str eq "b\x{1d0}f\x{101}ngsh\x{16b}o") {
      $str = "b\x{1d0}f\x{101}ngshu\x{14d}";
      
    } elsif ($str eq "sho\x{fa}x\x{12b}") {
      $str = "sh\x{f3}ux\x{12b}";
    }
  }
  
  # Correct certain records that are missing an abbreviated form
  if ((scalar(@$aa) == 1) and (scalar(@$bb) == 2)) {
    if ($aa->[0] eq "sh\x{113}ngy\x{12b}n") {
      push @$aa, ("sh\x{113}ng");
    
    } elsif ($aa->[0] eq "b\x{1ce}ozh\x{e8}ng") {
      push @$aa, ("zh\x{e8}ng");
    
    } elsif ($aa->[0] eq "b\x{f9}zh\x{ec}") {
      unshift @$aa, ("b\x{f9}");
      
    } elsif ($aa->[0] eq "f\x{1ce}ngw\x{e8}n") {
      push @$aa, ("f\x{1ce}ng");
    
    } elsif ($aa->[0] eq "g\x{1d4}j\x{12b}") {
      push @$aa, ("j\x{12b}");
    
    } elsif ($aa->[0] eq "ji\x{e0}nji\x{e0}n") {
      push @$aa, ("ji\x{e0}n");
      
    } elsif ($aa->[0] eq "m\x{f2}m\x{f2}") {
      push @$aa, ("m\x{f2}");
    }
  }
}

# match_pinyin(\@hws, \@pnys, $vlevel, $lnum)
#
# Intelligently match Pinyin readings to the proper headwords.  The
# return value is a list of array references.  Each referenced array
# has the first value being one of the values from @hws and the second
# value being an array reference storing all the Pinyin readings in
# order for that particular headword.
#
# The vlevel and lnum parameters are only for diagnostic messages so the
# user can determine where in the TOCFL data files Pinyin matching
# failed.
#
sub match_pinyin {
  # Get and check parameters
  ($#_ == 3) or die "Wrong number of parameters, stopped";
  my $hr     = shift;
  my $pr     = shift;
  my $vlevel = shift;
  my $lnum   = shift;
  
  ((ref($hr) eq 'ARRAY') and (ref($pr) eq 'ARRAY')) or
    die "Wrong parameter types, stopped";
  ((not ref($vlevel)) and (not ref($lnum))) or
    die "Wrong parameter types, stopped";
  
  # FIRST EXCEPTIONAL CASE =============================================
  
  # If there are the exact same number of Han and Pinyin renderings,
  # check for the special case where each element corresponds in length
  my $special_case = 0;
  if (scalar(@$hr) == scalar(@$pr)) {
    $special_case = 1;
    for(my $i = 0; $i < scalar(@$hr); $i++) {
      unless (han_count($hr->[$i]) == pinyin_count($pr->[$i])) {
        $special_case = 0;
        last;
      }
    }
  }
  
  # If we got this first special case, just match each headword with the
  # corresponding pinyin and return that without proceeding further
  if ($special_case) {
    my @sresult;
    for(my $i = 0; $i < scalar(@$hr); $i++) {
      push @sresult, ([$hr->[$i], [ $pr->[$i] ] ]);
    }
    return @sresult;
  }
  
  # SECOND EXCEPTIONAL CASE ============================================
  
  # See if everything has an exceptional mapping
  $special_case = 1;
  for my $h (@$hr) {
    unless (defined han_exmap($h)) {
      $special_case = 0;
      last;
    }
  }
  
  # If everything does have an exceptional mapping, check if the
  # exceptional mapping case applies
  if ($special_case) {
    # Get a hash of all Pinyin readings of this word and set each to a
    # value of zero
    my %pyh;
    for my $p (@$pr) {
      $pyh{$p} = 0;
    }
    
    # Check that all exceptional mappings are in the hash and set all of
    # the hash values to one
    for my $h (@$hr) {
      if (defined $pyh{han_exmap($h)}) {
        $pyh{han_exmap($h)} = 1;
        
      } else {
        $special_case = 0;
        last;
      }
    }
    
    # If special case flag still on, check finally that all values in
    # the hash have been set to one
    if ($special_case) {
      for my $v (values %pyh) {
        unless ($v) {
          $special_case = 0;
          last;
        }
      }
    }
  }
  
  # If we got the exceptional mapping case, just match each headword
  # with Pinyin from the exceptional mapping function and return that
  if ($special_case) {
    my @sresult;
    for(my $i = 0; $i < scalar(@$hr); $i++) {
      push @sresult, ([$hr->[$i], [ han_exmap($hr->[$i]) ] ]);
    }
    return @sresult;
  }
  
  # GENERAL CASE =======================================================
  
  # General case -- start a mapping with character/syllable length as
  # the key, and start out by setting the lengths of all Han renderings
  # as keys, with the value of each set to zero if there is a single Han
  # rendering with that length or one if there are multiple Han
  # renderings with that length
  my %lh;
  for my $h (@$hr) {
    my $key = han_count($h);
    if (defined $lh{"$key"}) {
      $lh{"$key"} = 1;
    } else {
      $lh{"$key"} = 0;
    }
  }
  
  # Compute the length in syllables of each Pinyin rendering, and for
  # each verify that the length is already in the length mapping and
  # that the mapped value is zero or one or three, then set the mapped
  # value to two if it is one or three if it is zero
  for my $p (@$pr) {
    # Compute length
    my $syl_count = pinyin_count($p);
    
    # Now begin verification, first checking that there is a Han
    # rendering with the same length
    if (defined $lh{"$syl_count"}) {
      # Second, check cases
      if (($lh{"$syl_count"} == 0) or ($lh{"$syl_count"} == 3)) {
        # Only a single Han rendering of this length, so we can have
        # any number of Pinyin for it; always set to 3 after one is
        # found so we can make sure every Han record was matched
        $lh{"$syl_count"} = 3;
        
      } elsif ($lh{"$syl_count"} == 1) {
        # Multiple Han renderings of this length that haven't been
        # claimed yet, so claim them
        $lh{"$syl_count"} = 2;
        
      } else {
        die "File $vlevel line $lnum: Pinyin matching failed, stopped";
      }
      
    } else {
      die "File $vlevel line $lnum: Pinyin matching failed, stopped";
    }
  }
  
  # Make sure that every Han record was matched; all values in the
  # length hash should be either 2 or 3
  for my $v (values %lh) {
    (($v == 2) or ($v == 3)) or
      die "File $vlevel line $lnum: Pinyin matching failed, stopped";
  }
  
  # Build the result array in general case
  my @result;
  for(my $i = 0; $i < scalar(@$hr); $i++) {
    # Get current Han reading and its count
    my $hanr = $hr->[$i];
    my $hanc = han_count($hanr);

    # Accumulate all Pinyin that have the same count
    my @pys;
    for my $p (@$pr) {
      if (pinyin_count($p) == $hanc) {
        push @pys, ($p);
      }
    }
    
    # Add the new record to result
    push @result, ([$hanr, \@pys ]);
  }
  
  # Return result array in general case
  return @result;
}

# ==================
# Program entrypoint
# ==================

# Check that there are no program arguments
#
($#ARGV < 0) or die "Not expecting program arguments, stopped";

# Check that there are seven TOCFL data files in the configuration
# variable and that each is a scalar that references an existing file
#
(ref($config_tocfl) eq 'ARRAY') or
  die "Invalid TOCFL configuration, stopped";
(scalar(@$config_tocfl) == 7) or
  die "Invalid TOCFL configuration, stopped";
for my $fpath (@$config_tocfl) {
  (not ref($fpath)) or die "Invalid TOCFL configuration, stopped";
  (-f $fpath) or die "Can't find TOCFL file '$fpath', stopped";
}

# Open database connection to existing database
#
my $dbc = Sino::DB->connect($config_dbpath, 0);

# Start a read-write transaction for everything
#
my $dbh = $dbc->beginWork('rw');

# Check that nothing in the wclass table or the word table
#
my $ecq = $dbh->selectrow_arrayref('SELECT wclassid FROM wclass');
(not (ref($ecq) eq 'ARRAY')) or
  die "Database already has records, stopped";

$ecq = $dbh->selectrow_arrayref('SELECT wordid FROM word');
(not (ref($ecq) eq 'ARRAY')) or
  die "Database already has records, stopped";

# Define hash that will store mapping of word-class names to their
# numeric IDs
#
my %wcm;

# Add all the word class information to the database; this dataset is
# derived from an auxiliary datasheet that accompanies the TOCFL data
#
for my $wcrec (
    [ 1, 'Adv'    , 'adverb'                              ],
    [ 2, 'Conj'   , 'conjunction'                         ],
    [ 3, 'Det'    , 'determiner'                          ],
    [ 4, 'M'      , 'measure'                             ],
    [ 5, 'N'      , 'noun'                                ],
    [ 6, 'Prep'   , 'preposition'                         ],
    [ 7, 'Ptc'    , 'particle'                            ],
    [ 8, 'V'      , 'verb'                                ],
    [ 9, 'Vi'     , 'intransitive action verb'            ],
    [10, 'V-sep'  , 'intransitive action verb, separable' ],
    [11, 'Vs'     , 'intransitive state verb'             ],
    [12, 'Vst'    , 'transitive state verb'               ],
    [13, 'Vs-attr', 'intransitive state verb, attributive'],
    [14, 'Vs-pred', 'intransitive state verb, predicative'],
    [15, 'Vs-sep' , 'intransitive state verb, separable'  ],
    [16, 'Vaux'   , 'auxiliary verb'                      ],
    [17, 'Vp'     , 'intransitive process verb'           ],
    [18, 'Vpt'    , 'transitive process verb'             ],
    [19, 'Vp-sep' , 'intransitive process verb, separable']
  ) {
  
  $dbh->do(
    'INSERT INTO wclass(wclassid, wclassname, wclassfull) '
    . 'VALUES (?,?,?)',
    undef,
    $wcrec->[0],
    $wcrec->[1],
    $wcrec->[2]);
  $wcm{$wcrec->[1]} = $wcrec->[0];
}

# Process files level by level
#
for(my $vlevel = 1; $vlevel <= 7; $vlevel++) {

  # Open the file for reading in UTF-8 with CR+LF translation
  my $fpath = $config_tocfl->[$vlevel - 1];
  open(my $fh, "< :encoding(UTF-8) :crlf", $fpath) or
    die "Failed to open '$fpath', stopped";
  
  # Now read line-by-line
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
    
    # Drop ZWSP
    $ltext =~ s/\x{200b}//g;
    
    # Replace variant lowercase a with ASCII lowercase a
    $ltext =~ s/\x{251}/a/g;
    
    # Replace lowercase breves with lowercase carons
    $ltext =~ s/\x{103}/\x{1ce}/g;
    $ltext =~ s/\x{12d}/\x{1d0}/g;
    $ltext =~ s/\x{14f}/\x{1d2}/g;
    $ltext =~ s/\x{16d}/\x{1d4}/g;
    
    # Make sure no ? character used
    (not ($ltext =~ /\?/)) or
      die "File $vlevel line $lnum: Invalid ? character, stopped";
    
    # If row ends with a comma and optional whitespace, insert a ? at
    # end so we still split properly
    $ltext =~ s/,[ \t]*\z/,\?/;
    
    # Parse into three or four fields with comma separator
    my @rec = split /,/, $ltext;
    (($#rec == 2) or ($#rec == 3)) or
      die "File $vlevel line $lnum: Wrong number of fields, stopped";
    
    # If we got four fields, the first is the optional word topic, which
    # we will not be including, so drop it
    if ($#rec == 3) {
      shift @rec;
    }
    
    # If last field is the special ? we inserted, change to blank
    $rec[2] =~ s/\A[ \t]*\?[ \t]*\z//;
    
    # For each field, trim leading and trailing whitespace, then drop
    # leading and trailing quotes if present, then trim leading and
    # trailing whitespace again
    for my $fv (@rec) {
      $fv =~ s/\A[ \t]*(?:["'][ \t]*)?//;
      $fv =~ s/(?:[ \t]*["'])?[ \t]*\z//;
    }
  
    # Drop Bopomofo parentheticals and empty parentheticals in headword
    # and whitespace trim once again
    $rec[0] =~ s/\([ \t\x{2ca}-\x{2d9}\x{3100}-\x{3129}]*\)//g;
    $rec[0] =~ s/\A[ \t]+//;
    $rec[0] =~ s/[ \t+]\z//;
    
    # Get sequence of headwords, pinyin, and parts-of-speech by
    # splitting fields on forward slash
    my @hwsa  = split /\//, $rec[0];
    my @pnysa = split /\//, $rec[1];
    my @wcs   = split /\//, $rec[2];
    
    # For headwords and pinyin, elements that have a parenthetical
    # should be split into two separate entries, one with the
    # parenthetical and one without; we already dropped Bopomofo
    # parentheticals earlier so those won't be handled here; we will
    # create new arrays @hws and @pnys that store the expanded entries
    my @hws;
    my @pnys;
    for(my $i = 0; $i < 2; $i++) {
      # Get references to the source array and target array we are
      # handling here
      my $sa;
      my $ta;
      if ($i == 0) {
        $sa = \@hwsa;
        $ta = \@hws;
        
      } elsif ($i == 1) {
        $sa = \@pnysa;
        $ta = \@pnys;
        
      } else {
        die "Unexpected";
      }
      
      # Go through each element in the source array and either copy
      # as-is to target array or split into two elements in target
      # array; also, do duplication checks so that duplicates are never
      # inserted while decoding
      for my $sv (@$sa) {
        # Handle cases
        if ($sv =~ /\A
                      ([^\(\)]*)
                      \(
                      ([^\(\)]*)
                      \)
                      ([^\(\)]*)
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
            die "File $vlevel line $lnum: Empty optional, stopped";
          
          # Make sure either prefix or suffix (or both) is non-empty
          ((length($prefix) > 0) or (length($suffix) > 0)) or
            die "File $vlevel line $lnum: Invalid optional, stopped";
          
          # Insert both without and with the optional, but only if not
          # already in the target array
          for my $iv ($prefix . $suffix, $prefix . $option . $suffix) {
            my $dup_found = 0;
            for my $dvc (@$ta) {
              if ($iv eq $dvc) {
                $dup_found = 1;
                last;
              }
            }
            unless ($dup_found) {
              push @$ta, ($iv);
            }
          }
          
        } elsif ($sv =~ /\A[^\(\)]*\z/) {
          # No parentheticals, so begin by whitespace trimming
          $sv =~ s/\A[ \t]+//;
          $sv =~ s/[ \t]+\z//;
          
          # Make sure after trimming not empty
          (length($sv) > 0) or
            die "File $vlevel line $lnum: Empty component, stopped";
          
          # Push into target array, but only if not already in the
          # target array
          my $dup_found = 0;
          for my $dvc (@$ta) {
            if ($sv eq $dvc) {
              $dup_found = 1;
              last;
            }
          }
          unless ($dup_found) {
            push @$ta, ($sv);
          }
          
        } else {
          # Other cases are invalid
          die "File $vlevel line $lnum: Invalid record, stopped";
        }
      }
    }
  
    # We already did whitespace trimming and blank detection within @hws
    # and @pnys; now do whitespace trimming and blank detection within
    # @wcs
    for my $cv (@wcs) {
      $cv =~ s/\A[ \t]+//;
      $cv =~ s/[ \t]+\z//;
      (length($cv) > 0) or
        die "File $vlevel line $lnum: Blank word class, stopped";
    }
    
    # Go through all the headwords and make sure only characters of
    # General Category Letter-Other (Lo) are used
    for my $fv (@hws) {
      ($fv =~ /\A[\p{Lo}]+\z/) or
        die "File $vlevel line $lnum: Invalid headword char, stopped";
    }
    
    # Go through all the Pinyin, convert initial uppercase to lowercase
    # (only occurs in five records for religious names), and make sure
    # only the allowed lowercase letters and diacritic letters are used
    for my $fv (@pnys) {
      if ($fv =~ /\A[A-Z][^A-Z]*\z/) {
        $fv =~ tr/A-Z/a-z/;
      }
      
      for my $c (split //, $fv) {
        my $cpv = ord($c);
        ((($cpv >= ord('a')) and ($cpv <= ord('z'))) or
          ($cpv == 0xe0) or ($cpv == 0xe1) or
          ($cpv == 0xe8) or ($cpv == 0xe9) or
          ($cpv == 0xec) or ($cpv == 0xed) or
          ($cpv == 0xf2) or ($cpv == 0xf3) or
          ($cpv == 0xf9) or ($cpv == 0xfa) or
          ($cpv == 0x101) or ($cpv == 0x113) or ($cpv == 0x12b) or
            ($cpv == 0x14d) or ($cpv == 0x16b) or
          ($cpv == 0x1ce) or ($cpv == 0x11b) or ($cpv == 0x1d0) or
            ($cpv == 0x1d2) or ($cpv == 0x1d4) or
          ($cpv == 0xfc) or ($cpv == 0x1d6) or ($cpv == 0x1d8) or
            ($cpv == 0x1da) or ($cpv == 0x1dc)) or
          die "File $vlevel line $lnum: Invalid pinyin char, stopped";
      }
    }
    
    # Apply fixes to the Pinyin array to correct for typos and errors in
    # the TOCFL data
    pinyin_fix(\@pnys, \@hws);
    
    # Go through all the Word classes and make sure only ASCII letters
    # and hyphen are used, and that first character is letter; also,
    # normalize case within word classes, so that all word classes begin
    # with uppercase letter and any remaining characters are lowercase
    for my $fv (@wcs) {
      # Check format and split into prefix and suffix
      ($fv =~ /\A([A-Za-z])([A-Za-z\-]*)\z/) or
        die "File $vlevel line $lnum: Invalid class char, stopped";
      my $prefix = $1;
      my $suffix = $2;
      
      # Uppercase prefix and lowercase suffix
      $prefix =~ tr/a-z/A-Z/;
      $suffix =~ tr/A-Z/a-z/;
      
      # Update word class with normalized form
      $fv = $prefix . $suffix;
    }
    
    # Make sure at least one headword and at least one Pinyin, but there
    # are records where there are no word classes
    ($#hws >= 0) or
      die "File $vlevel line $lnum: No headword, stopped";
    ($#pnys >= 0) or
      die "File $vlevel line $lnum: No Pinyin, stopped";
    
    # Make sure within each field there are no duplicate components
    # remaining
    for(my $i = 0; $i < 3; $i++) {
      # Get source array reference
      my $sa;
      if ($i == 0) {
        $sa = \@hws;
      } elsif ($i == 1) {
        $sa = \@pnys;
      } elsif ($i == 2) {
        $sa = \@wcs;
      } else {
        die "Unexpected";
      }
      
      # Check everything but the last
      for(my $j = 0; $j < scalar(@$sa) - 1; $j++) {
        # Check against all elements that follow this one
        for(my $k = $j + 1; $k < scalar(@$sa); $k++) {
          ($sa->[$j] ne $sa->[$k]) or
            die "File $vlevel line $lnum: Duplicate values, stopped";
        }
      }
    }
    
    # We now have all word classes, so go through the word class list
    # and replace everything with the numeric ID value, checking that
    # each is recognized
    for my $wcv (@wcs) {
      (defined $wcm{$wcv}) or
        die "Unrecognized word class '$wcv', stopped";
      $wcv = $wcm{$wcv};
    }
    
    # Look through all the headwords and determine the IDs of any
    # existing words that share any of those headwords
    my %sharemap;
    for my $hwv (@hws) {
      my $qck = $dbh->selectrow_arrayref(
                    'SELECT wordid FROM han WHERE hantrad=?',
                    undef,
                    encode('UTF-8', $hwv,
                            Encode::FB_CROAK | Encode::LEAVE_SRC));
      if (ref($qck) eq 'ARRAY') {
        $sharemap{"$qck->[0]"} = 1;
      }
    }
    my @sharelist = map(int, keys %sharemap);
    
    # Check that we don't have more than one share
    ($#sharelist < 1) or die "Can't handle multi-mergers, stopped";
    
    # Either add a brand-new word or merge this word into an already
    # existing one
    my $wordid;
    if ($#sharelist < 0) {
      # Insert a brand-new word; determine new word ID as one greater
      # than greatest existing, or 1 if this is the first
      $wordid = wordid_new($dbc);
      
      # Insert the new word record
      $dbh->do('INSERT INTO word(wordid, wordlevel) VALUES (?,?)',
                undef,
                $wordid, $vlevel);
    
    } elsif ($#sharelist == 0) {
      # We have an existing word we need to merge this entry into, so
      # get the wordid of this existing word
      $wordid = $sharelist[0];
      
    } else {
      die "Unexpected";
    }
    
    # Add all word classes that aren't already registered for the word
    for my $wcv (@wcs) {
      wc_addifnew($dbc, $wordid, $wcv);
    }
    
    # Now add all Han readings and Pinyin readings associated with that
    for my $aa (match_pinyin(\@hws, \@pnys, $vlevel, $lnum)) {
      my $han_id = han_addifnew($dbc, $wordid, $aa->[0]);
      for my $bb (@{$aa->[1]}) {
        pny_addifnew($dbc, $han_id, $bb);
      }
    }
  }
  
  # Close the file
  close($fh);
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
