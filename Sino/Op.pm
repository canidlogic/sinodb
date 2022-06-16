package Sino::Op;
use parent qw(Exporter);
use strict;

our @EXPORT_OK = qw(
                  string_to_db
                  db_to_string
                  wordid_new
                  enter_han
                  enter_wordclass
                  enter_pinyin
                  enter_ref
                  enter_atom);

# Core dependencies
use Encode qw(decode encode);

# Sino modules
use Sino::Util qw(pinyin_split);

=head1 NAME

Sino::Op - Sino database operations module.

=head1 SYNOPSIS

  use Sino::Op qw(
        string_to_db
        db_to_string
        wordid_new
        enter_han
        enter_wordclass
        enter_pinyin
        enter_ref
        enter_atom);
  
  # Convert Unicode string to binary format needed for SQLite
  my $database_string = string_to_db($unicode_string);
  
  # Convert binary format for SQLite into Unicode string
  my $unicode_string = db_to_string($database_string);
  
  # Other operations require a database connection
  use Sino::DB;
  use SinoConfig;
  my $dbc = Sino::DB->connect($config_dbpath, 0);
  
  # Get a new word ID (should be within a work block!)
  my $dbh = $dbc->beginWork('rw');
  my $word_id = wordid_new($dbc);
  ...
  $dbc->finishWork;
  
  # Enter a Han reading of a specific word ID and get the hanid
  my $han_id = enter_han($dbc, $word_id, $han_reading);
  
  # Enter a word class of a specific word ID
  enter_wordclass($dbc, $word_id, 'Adv');
  
  # Enter a Pinyin reading of a specific Han reading
  enter_pinyin($dbc, $han_id, $pinyin);
  
  # Enter a reference in the ref table if it doesn't already exist, and
  # in all cases return the refid for the reference
  my $ref_id = enter_ref($dbc, $trad, $simp, $pinyin);
  
  # Enter an atom if it doesn't already exist, and in all cases return
  # the atmid for the atom
  my $atom_id = enter_atom($dbc, 'example');

=head1 DESCRIPTION

Provides various database operation functions.  See the documentation of
the individual functions for further information.

=cut

=head1 FUNCTIONS

=over 4

=item B<string_to_db($str)>

Get a binary UTF-8 string copy of a given Unicode string.

Since C<Sino::DB> sets SQLite to operate in binary string mode, you must
encode any Unicode string into a binary string with this function before
you can pass it through to SQLite.

If you know the string only contains US-ASCII, this function is
unnecessary.

=cut

sub string_to_db {
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  
  # Return the UTF-8 binary encoding (in-place modification OK)
  return encode('UTF-8', $str, Encode::FB_CROAK);
}

=item B<db_to_string($str)>

Get a Unicode string copy of a given binary UTF-8 string.

Since C<Sino::DB> sets SQLite to operate in binary string mode, you must
decode any binary UTF-8 string received from SQLite with this function
before you can use it as a Unicode string in Perl.

If you know the string only contains US-ASCII, this function is
unnecessary.

=cut

sub db_to_string {
  # Get and check parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  
  # Return the Unicode decoding (in-place modification OK)
  return decode('UTF-8', $str, Encode::FB_CROAK);
}

=item B<wordid_new(dbc)>

Given a C<Sino::DB> database connection, get a new word ID to use.  If
no words are defined yet, the new word ID will be 1.  Otherwise, it will
be one greater than the maximum word ID currently in use.

B<Caution:> A race will occur between the time you get the new ID and
the time you attempt to use the new ID, unless you call this function in
the same work block that defines the new word.

=cut

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

=item B<enter_han(dbc, wordid, hantrad)>

Given a C<Sino::DB> database connection, a word ID, and a Han
traditional character rendering, add it as a Han reading of the given
word ID unless it is already present in the han table.  In all cases,
return a C<hanid> corresponding to this reading in the han table.

Fatal errors occur if the given word ID is not in the word table, or if
the Han traditional character rendering is already used for a different
word ID.

C<hantrad> should be a Unicode string, not a binary string.  A r/w work
block will start in this function, so don't call this function within a
read-only block.

=cut

sub enter_han {
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
  
  # Encode traditional reading in binary
  $hantrad = string_to_db($hantrad);
  
  # Start a read/write work block
  my $dbh = $dbc->beginWork('rw');
  
  # Make sure that the given word ID is defined in the word table
  my $qr = $dbh->selectrow_arrayref(
                  'SELECT wordid FROM word WHERE wordid=?',
                  undef,
                  $wordid);
  (ref($qr) eq 'ARRAY') or die "Given word ID not defined, stopped";
  
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
    # Make sure the given traditional reading is not yet used in the han
    # table
    $qr = $dbh->selectrow_arrayref(
                  'SELECT hanid FROM han WHERE hantrad=?',
                  undef,
                  $hantrad);
    (not (ref($qr) eq 'ARRAY')) or
      die "Given Han reading already used for different word, stopped";
    
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

=item B<enter_wordclass(dbc, wordid, wclassname)>

Given a C<Sino::DB> database connection, a word ID, and the name of a
word class, add that word class to the given word ID unless it is
already present in the wc table.

C<wclassname> is the ASCII name of the word class.  This must be in the
wclass table already or a fatal error occurs.  Also, the given word ID
must already be in the word table or a fatal error occurs.

A r/w work block will start in this function, so don't call this
function within a read-only block.
#
# This function does not check that the given wordid actually exists in
# the word table, and it does not check that wclassid actually is a
# valid foreign key.
=cut

sub enter_wordclass {
  # Get and check parameters
  ($#_ == 2) or die "Wrong parameter count, stopped";
  
  my $dbc = shift;
  (ref($dbc) and $dbc->isa('Sino::DB')) or
    die "Wrong parameter type, stopped";
  
  my $wordid     = shift;
  my $wclassname = shift;
  
  ((not ref($wordid)) and (not ref($wclassname))) or
    die "Wrong parameter type, stopped";
  
  (int($wordid) == $wordid) or
    die "Wrong parameter type, stopped";
  $wordid = int($wordid);
  ($wordid >= 0) or die "Parameter out of range, stopped";
  
  $wclassname = string_to_db($wclassname);
  
  # Start a read/write work block
  my $dbh = $dbc->beginWork('rw');
  
  # Make sure that the given word ID is defined in the word table
  my $qr = $dbh->selectrow_arrayref(
                  'SELECT wordid FROM word WHERE wordid=?',
                  undef,
                  $wordid);
  (ref($qr) eq 'ARRAY') or die "Given word ID not defined, stopped";
  
  # Look up the word class ID
  $qr = $dbh->selectrow_arrayref(
                'SELECT wclassid FROM wclass WHERE wclassname=?',
                undef,
                $wclassname);
  (ref($qr) eq 'ARRAY') or
    die "Given word class not recognized, stopped";
  
  my $wclass_id = $qr->[0];
  
  # Find whether the given word class already exists for this word
  $qr = $dbh->selectrow_arrayref(
                'SELECT wcid FROM wc WHERE wordid=? AND wclassid=?',
                undef,
                $wordid, $wclass_id);
  
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
        $wordid, $wc_ord, $wclass_id);
  }
  
  # Finish the work block if we got here
  $dbc->finishWork;
}

=item B<enter_pinyin(dbc, hanid, pny)>

Given a C<Sino::DB> database connection, a Han ID, and a Pinyin reading,
add it as a Pinyin reading of the given Han ID unless it is already
present in the pny table.

C<pny> should be a Unicode string, not a binary string.  It must pass
the C<pinyin_split()> function in C<Sino::Util> to check for validity or
a fatal error occurs.  The given Han ID must exist in the han table or a
fatal error occurs.  A r/w work block will start in this function, so
don't call this function within a read-only block.

=cut

sub enter_pinyin {
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
  
  # Validate Pinyin
  pinyin_split($pny);
  
  # Encode Pinyin in binary
  $pny = string_to_db($pny);
  
  # Start a read/write work block
  my $dbh = $dbc->beginWork('rw');
  
  # Make sure that the given han ID is defined in the han table
  my $qr = $dbh->selectrow_arrayref(
                  'SELECT hanid FROM han WHERE hanid=?',
                  undef,
                  $hanid);
  (ref($qr) eq 'ARRAY') or die "Given Han ID not defined, stopped";
  
  # Find whether the given Pinyin already exists for this word
  $qr = $dbh->selectrow_arrayref(
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

=item B<enter_ref(dbc, trad, simp, pinyin)>

Given a C<Sino::DB> database connection, a traditional Han reading, a
simplified Han reading, and optionally a Pinyin reading, enter this
reference in the ref table if not already present, and in all cases
return a C<refid> corresponding to the given reference. 

C<trad> C<simp> and C<pinyin> should be Unicode strings, not a binary
strings.  C<pinyin> may also be C<undef> for cases where a Pinyin 
reading isn't part of the reference, or where a main entry has Pinyin
that doesn't normalize.  If traditional and simplified readings are the
same, pass the same string for both parameters.  Traditional and
simplified readings may only include characters from the core CJK
Unicode block.  The given C<pinyin> must pass C<pinyin_split> in
C<Sino::Util> to verify that it is normalized (unless it is C<undef>).

A r/w work block will start in this function, so don't call this
function within a read-only block.

=cut

sub enter_ref {
  # Get and check parameters
  ($#_ == 3) or die "Wrong parameter count, stopped";
  
  my $dbc = shift;
  (ref($dbc) and $dbc->isa('Sino::DB')) or
    die "Wrong parameter type, stopped";
  
  my $trad   = shift;
  my $simp   = shift;
  my $pinyin = shift;
  
  ((not ref($trad)) and (not ref($simp))) or
    die "Wrong parameter type, stopped";
  
  ($trad =~ /\A[\x{4e00}-\x{9fff}]+\z/) or
    die "Invalid Han characters in reference, stopped";
  ($simp =~ /\A[\x{4e00}-\x{9fff}]+\z/) or
    die "Invalid Han characters in reference, stopped";
  
  if (defined $pinyin) {
    (not ref($pinyin)) or die "Wrong parameter type, stopped";
    pinyin_split($pinyin);
  }
  
  # Encode parameters binary
  $trad = string_to_db($trad);
  $simp = string_to_db($simp);
  if (defined $pinyin) {
    $pinyin = string_to_db($pinyin);
  }
  
  # Start a read/write work block
  my $dbh = $dbc->beginWork('rw');
  
  # Find whether the given reference already exists
  my $qr;
  if (defined $pinyin) {
    $qr = $dbh->selectrow_arrayref(
                  'SELECT refid FROM ref '
                  . 'WHERE reftrad=? AND refsimp=? AND refpny=?',
                  undef,
                  $trad, $simp, $pinyin);
  } else {
    $qr = $dbh->selectrow_arrayref(
                  'SELECT refid FROM ref '
                  . 'WHERE reftrad=? AND refsimp=? AND refpny ISNULL',
                  undef,
                  $trad, $simp);
  }
  
  # Proceed depending whether record already exists
  my $ref_id;
  if (ref($qr) eq 'ARRAY') {
    # Reference already exists, so just use the existing ref_id
    $ref_id = $qr->[0];
    
  } else {
    # Reference doesn't already exist, so get one beyond current maximum
    # reference ID, or 1 if no references yet
    $ref_id = 1;
    $qr = $dbh->selectrow_arrayref(
                  'SELECT refid FROM ref ORDER BY refid DESC');
    if (ref($qr) eq 'ARRAY') {
      $ref_id = $qr->[0] + 1;
    }
    
    # Insert new reference into table
    if (defined $pinyin) {
      $dbh->do(
          'INSERT INTO ref(refid, reftrad, refsimp, refpny) '
          . 'VALUES (?, ?, ?, ?)',
          undef,
          $ref_id, $trad, $simp, $pinyin);
    
    } else {
      $dbh->do(
          'INSERT INTO ref(refid, reftrad, refsimp) '
          . 'VALUES (?, ?, ?)',
          undef,
          $ref_id, $trad, $simp);
    }
  }
  
  # Finish the work block if we got here
  $dbc->finishWork;
  
  # Return the ref_id
  return $ref_id;
}

=item B<enter_atom(dbc, str)>

Given a C<Sino::DB> database connection and a string, enter the string
in the atom table if not already present and in all cases return a
C<atmid> corresponding to the appropriate atom record.

C<str> should be a Unicode string, not a binary string.  It may contain
any Unicode codepoints except for ASCII control codes and surrogates.
(Supplemental codepoints are OK.)  An empty string I<is> an acceptable
atom string.

A r/w work block will start in this function, so don't call this
function within a read-only block.

=cut

sub enter_atom {
  # Get and check parameters
  ($#_ == 1) or die "Wrong parameter count, stopped";
  
  my $dbc = shift;
  (ref($dbc) and $dbc->isa('Sino::DB')) or
    die "Wrong parameter type, stopped";
  
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  
  ($str =~ /\A[\x{20}-\x{7e}\x{80}-\x{d7ff}\x{e000}-\x{10ffff}]*\z/) or
    die "Invalid codepoints in atom string, stopped";
  
  # Encode string binary
  $str = string_to_db($str);
  
  # Start a read/write work block
  my $dbh = $dbc->beginWork('rw');
  
  # Find whether the given atom already exists
  my $qr;
  $qr = $dbh->selectrow_arrayref(
                'SELECT atmid FROM atm WHERE atmval=?',
                undef,
                $str);
  
  # Proceed depending whether record already exists
  my $atom_id;
  if (ref($qr) eq 'ARRAY') {
    # Atom already exists, so just use the existing atom_id
    $atom_id = $qr->[0];
    
  } else {
    # Atom doesn't already exist, so get one beyond current maximum atom
    # ID, or 1 if no atoms yet
    $atom_id = 1;
    $qr = $dbh->selectrow_arrayref(
                  'SELECT atmid FROM atm ORDER BY atmid DESC');
    if (ref($qr) eq 'ARRAY') {
      $atom_id = $qr->[0] + 1;
    }
    
    # Insert new atom into table
    $dbh->do(
        'INSERT INTO atm(atmid, atmval) VALUES (?, ?)',
        undef,
        $atom_id, $str);
  }
  
  # Finish the work block if we got here
  $dbc->finishWork;
  
  # Return the atom_id
  return $atom_id;
}

=back

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

# End with something that evaluates to true
#
1;
