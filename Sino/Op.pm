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
                  enter_atom
                  words_xml);

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
        enter_atom
        words_xml);
  
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
  
  # Get an XML representation for a given sequence of words
  my $xml = words_xml($dbc, [5, 24, 351]);

=head1 DESCRIPTION

Provides various database operation functions.  See the documentation of
the individual functions for further information.

=head2 XML description format

This subsection documents the XML format used in the C<words_xml>
function.

The overall structure of the document is summarized as follows:

  <?xml version="1.0" encoding="UTF-8"?>
  <words>
    <word recid="5" level="2" wcs="..., ..., ...">
      <r han="..." pnys="..., ..., ...">
        <m trad="..." simp="..." pny="..." type="proper">
          <n type="msw" trad="..." simp="..." pny="..."/>
          <n type="alt" ctx="..." pny="..." cond="..."/>
          <n type="ref"
              desc="..."
              mode="..."
              trad="..." simp="..." pny="..."
              suff="..."/>
          ...
          <d sense="1" gloss="...">
            <c off="5" len="7" trad="..." simp="..." pny="..."/>
            ...
            <n type="msw" trad="..." simp="..." pny="..."/>
            ...
          </d>
          ...
        </m>
        ...
      </r>
      ...
    </word>
    
    <word recid="24" level="5" wclass="..., ..., ...">
      ...
    </word>
    
    ...
  </words>

An I<attribute list> is an attribute value containing a sequence of one
or more strings, where the separators between each string is a comma and
a space.  These lists are represented by C<..., ..., ...> in the example
above.

For any element shown in the example above where there are three
attributes C<trad> C<simp> and C<pny> the following rules apply.
C<trad> and C<simp> are required, giving the traditional reading and
the simplified reading.  If both traditional and simplified readings are
the same, both attributes are still required and both should have the
same value.  The C<pny> attribute is optional.  If present, it must
contain a normalized Pinyin pronunciation.

The top-level entity is a container element C<words> that contains
individual C<word> elements, which are each completely separate from
each other.  Allowing multiple word elements allows for multiple word
queries in one transaction, which is more efficient.

Each C<word> element is required to have a C<recid> attribute and a
C<level> attribute which identify the unique word ID within the Sino
database and the vocabulary level 1-9 associated with the word.
Optionally, word elements may have a C<wcs> element, which is a list
attribute of one or more word class names that apply to this word.  The
word classes, if present, come from the TOCFL data.

Word elements are also containers for one or more C<r> elements, which
define the individual readings of the word.  Each reading element must
have a C<han> attribute, which defines one specific Han reading of the
word.  Each reading element may optionally have a C<pnys> attribute,
which is an attribute list of one or more normalized Pinyin renderings
of this reading element.  The C<han> attribute is either from TOCFL or
COCT, except for level 9, where it is from CC-CEDICT.  The C<pnys>
attribute if present is from TOCFL.

Each reading element is also a container for zero or more C<m> elements,
which define the major meanings of the reading.  Each C<m> element has
required C<trad> and C<simp> attributes, as well as an optional C<pny>
attribute.  There is also an optional C<type> attribute which may have
the value C<common> or C<proper>, indicating meanings that CC-CEDICT
associates as not proper names or proper names, respectively; if not
specified, C<common> is assumed.  The C<trad> and C<simp> are according
to CC-CEDICT.  The C<han> of the parent C<r> element does I<not>
necessarily match C<trad>.  Sometimes it might match C<simp> instead, or
it could even match neither.  C<pny> is according to CC-CEDICT, so it
favors mainland pronunications.

Within each major meaning element is a sequence of zero or more
definition elements C<d>.  Each definition element must have a C<sense>
attribute that gives a sense number, as well as a C<gloss> attribute
that stores the actual gloss.

Both C<m> and C<d> elements may contain sequences of zero or more C<n>
elements, which represent annotations on their parent element.
Annotation elements must have a C<type> attribute with a value either
C<msw> C<alt> or C<ref> declaring the annotation type as either a
measure word (classifier), alternate pronunciation, or cross-reference.
There may be multiple annotations of each type.

Measure-word annotations have the required C<trad> and C<simp> 
attributes and the optional C<pny> attribute to associate a measure word
either with the whole meaning element or with a specific gloss.

Alternate-pronunciation annotations have optional C<ctx> and C<cond>
attributes defining the context in which the alternate pronunciation is
used and any special conditions or meanings attached to the alternate
pronunication.  All such annotations of course also have a required
C<pny> attribute defining the normalized Pinyin of the alternate
pronunication.  Since these annotations comes from CC-CEDICT, Taiwanese
pronunications are considered an "alternate" pronunication.  These
annotations associate the alternate pronunication either with the whole
meaning element or with a specific gloss.

Cross-reference annotations have optional C<mode> C<desc> and C<suff>
attributes defining a cross-reference mode, a descriptor modifier of
that mode, and a suffix with more information about the cross-reference.
Cross-reference annotations must have C<trad> and C<simp> attributes and
optionally a C<pny> attribute.  These annotations associate the
cross-reference either with the whole meaning element or with a specific
gloss.

Definition elements may also contain zero or more C<c> elements, which
represent citations within the gloss.  Each citation must have C<off>
and C<len> attributes that define the codepoint offset and codepoint
length of the citation within the parent element's C<gloss> attribute,
as well as require C<trad> and C<simp> attributes and an optional C<pny>
field.  Citations will not overlap within the gloss, and each must
select a valid range of characters within the gloss.

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

=item B<words_xml(dbc, ids)>

Given a C<Sino::DB> database connection and a reference to an array
storing one or more word IDs, return a structured XML result containing
all the information about those words from the database.  See the
documentation at the top of this module for the specific XML format.

The returned XML text is a Unicode string that may include Unicode
codepoints.  If you need it in a binary string context, you should use
UTF-8 encoding, as that is what is declared in the XML header.

=cut

# _xml_att(str)
#
# Escape a Unicode string so that it may be used within a double-quoted
# XML attribute.  Also verifies that no invalid codepoints are used.
# Neither line breaks nor tabs are allowed.
#
sub _xml_att {
  # Get and check parameters
  ($#_ == 0) or die "Wrong parameter count, stopped";
  
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  
  # Escape ampersand first
  $str =~ s/&/&amp;/g;
  
  # Escape angle brackets and double quote, but leave single quotes
  # alone
  $str =~ s/</&lt;/g;
  $str =~ s/>/&gt;/g;
  $str =~ s/"/&quot;/g;
  
  # Check character range
  ($str =~
    /\A[\x{20}-\x{d7ff}\x{e000}-\x{fffd}\x{10000}-\x{10ffff}]*\z/)
      or die "Invalid codepoint in XML attribute, stopped";
  
  # Return escaped string
  return $str;
}

# _xml_attl(arrayref)
#
# Given an array reference to a sequence of one or more Unicode strings,
# return an attribute list value, properly escaped, that can be used
# within a double-quoted XML attribute.  Also verifies that no invalid
# codepoints are used.  Neither line breaks nor tabs are allowed, nor
# can commas be used within any value, nor can any value be empty or
# include whitespace.
#
sub _xml_attl {
  # Get and check parameters
  ($#_ == 0) or die "Wrong parameter count, stopped";
  
  my $ar = shift;
  (ref($ar) eq 'ARRAY') or die "Wrong parameter type, stopped";
  (scalar(@$ar) > 0) or die "Parameter is empty, stopped";
  
  # Encode result
  my $result;
  my $first = 1;
  for my $str (@$ar) {
    # Check type
    (not ref($str)) or die "Invalid array element, stopped";
    
    # Check that no commas or whitespace
    (not ($str =~ /[,\s]/)) or die "Invalid array codes, stopped";
    
    # Check that not empty
    (length($str) > 0) or die "Empty array element, stopped";
    
    # Add to result
    if ($first) {
      $result = _xml_att($str);
      $first = 0;
    } else {
      $result = $result . ", " . _xml_att($str);
    }
  }
  
  # Return result
  return $result;
}

# _xml_d(dbc, dfnid, dfnsen, dfntext)
#
# Given a database connection, a definition ID, a definition sense
# number, and a definition gloss (Unicode encoded), generate and return
# the complete XML for the corresponding <d> element, including any
# citations and annotations contained within, along with a line break at
# the end.
#
sub _xml_d {
  # Get and check parameters
  ($#_ == 3) or die "Wrong parameter count, stopped";
  
  my $dbc = shift;
  (ref($dbc) and $dbc->isa('Sino::DB')) or
    die "Wrong parameter type, stopped";
  
  my $dfn_id = shift;
  (not ref($dfn_id)) or die "Wrong parameter type, stopped";
  (int($dfn_id) == $dfn_id) or die "Wrong parameter type, stopped";
  $dfn_id = int($dfn_id);
  ($dfn_id >= 0) or die "Parameter out of range, stopped";
  
  my $dfn_sen = shift;
  (not ref($dfn_sen)) or die "Wrong parameter type, stopped";
  (int($dfn_sen) == $dfn_sen) or die "Wrong parameter type, stopped";
  $dfn_sen = int($dfn_sen);
  ($dfn_sen >= 0) or die "Parameter out of range, stopped";
  
  my $dfn_text = shift;
  (not ref($dfn_text)) or die "Wrong parameter type, stopped";
  
  # Start a read-only workblock
  my $dbh = $dbc->beginWork('r');
  my $qr;
  
  # Start the XML empty
  my $xml = '';
  
  # Flag indicating whether there are any child elements
  my $has_children = 0;
  
  # First comes the opening element
  $xml = $xml . sprintf("        <d sense=\"%d\" gloss=\"%s\">",
                          $dfn_sen, _xml_att($dfn_text));
  
  # Add any citations
  $qr = $dbh->selectall_arrayref(
                'SELECT citoff, citlen, reftrad, refsimp, refpny '
                . 'FROM cit '
                . 'INNER JOIN ref ON ref.refid = cit.refid '
                . 'WHERE dfnid=? '
                . 'ORDER BY citoff ASC',
                undef,
                $dfn_id);
  if (ref($qr) eq 'ARRAY') {
    for my $cite (@$qr) {
      # Set children flag
      $has_children = 1;
      
      # Get citation fields
      my $cite_off  = $cite->[0];
      my $cite_len  = $cite->[1];
      my $cite_trad = db_to_string($cite->[2]);
      my $cite_simp = db_to_string($cite->[3]);
      my $cite_pny  = $cite->[4];
      if (defined $cite_pny) {
        $cite_pny = db_to_string($cite_pny);
      }
      
      # Add this citation element
      my $cite_fmt;
      if (defined $cite_pny) {
        $cite_fmt = "\n          <c off=\"%d\" len=\"%d\" trad=\"%s\" "
                    . "simp=\"%s\" pny=\"%s\"/>";
      } else {
        $cite_fmt = "\n          <c off=\"%d\" len=\"%d\" trad=\"%s\" "
                    . "simp=\"%s\"/>";
      }
      
      if (defined $cite_pny) {
        $xml = $xml . sprintf($cite_fmt,
                              $cite_off,
                              $cite_len,
                              _xml_att($cite_trad),
                              _xml_att($cite_simp),
                              _xml_att($cite_pny));
      } else {
        $xml = $xml . sprintf($cite_fmt,
                              $cite_off,
                              $cite_len,
                              _xml_att($cite_trad),
                              _xml_att($cite_simp));
      }
    }
  }
  
  # Measure-word annotations
  $qr = $dbh->selectall_arrayref(
                'SELECT reftrad, refsimp, refpny '
                . 'FROM msd '
                . 'INNER JOIN ref ON ref.refid = msd.refid '
                . 'WHERE dfnid=? ORDER BY msdord ASC',
                undef,
                $dfn_id);
  if (ref($qr) eq 'ARRAY') {
    for my $msw (@$qr) {
      # Set children flag
      $has_children = 1;
      
      # Get measure word fields
      my $msw_trad = db_to_string($msw->[0]);
      my $msw_simp = db_to_string($msw->[1]);
      my $msw_pny  = $msw->[2];
      if (defined $msw_pny) {
        $msw_pny = db_to_string($msw_pny);
      }
      
      # Add this measure-word/classifier element
      my $msw_fmt;
      if (defined $msw_pny) {
        $msw_fmt = "\n          <n type=\"msw\" trad=\"%s\" "
                    . "simp=\"%s\" pny=\"%s\"/>";
      } else {
        $msw_fmt = "\n          <n type=\"msw\" trad=\"%s\" "
                    . "simp=\"%s\"/>";
      }
      
      if (defined $msw_pny) {
        $xml = $xml . sprintf($msw_fmt,
                              _xml_att($msw_trad),
                              _xml_att($msw_simp),
                              _xml_att($msw_pny));
      } else {
        $xml = $xml . sprintf($msw_fmt,
                              _xml_att($msw_trad),
                              _xml_att($msw_simp));
      }
    }
  }
  
  # Alternate-pronunciation annotations
  $qr = $dbh->selectall_arrayref(
              'SELECT tctx.atmval, tcnd.atmval, apdpny '
              . 'FROM apd '
              . 'INNER JOIN atm AS tctx ON tctx.atmid=apd.apdctx '
              . 'INNER JOIN atm AS tcnd ON tcnd.atmid=apd.apdcond '
              . 'WHERE dfnid=? ORDER BY apdord ASC',
              undef,
              $dfn_id);
  if (ref($qr) eq 'ARRAY') {
    for my $pr (@$qr) {
      # Set children flag
      $has_children = 1;
      
      # Get pronunciation fields
      my $pr_ctx  = db_to_string($pr->[0]);
      my $pr_cond = db_to_string($pr->[1]);
      my $pr_pny  = db_to_string($pr->[2]);
      
      if (length($pr_ctx) < 1) {
        $pr_ctx = undef;
      }
      if (length($pr_cond) < 1) {
        $pr_cond = undef;
      }
      
      # Add this alternate pronunciation element
      $xml = $xml . "\n          <n type=\"alt\"";
      $xml = $xml . sprintf(" pny=\"%s\"", _xml_att($pr_pny));
      if (defined $pr_ctx) {
        $xml = $xml . sprintf(" ctx=\"%s\"", _xml_att($pr_ctx));
      }
      if (defined $pr_cond) {
        $xml = $xml . sprintf(" cond=\"%s\"", _xml_att($pr_cond));
      }
      $xml = $xml . "/>";
    }
  }
  
  # Cross-reference annotations
  $qr = $dbh->selectall_arrayref(
              'SELECT reftrad, refsimp, refpny, '
              . 'td.atmval, tt.atmval, ts.atmval '
              . 'FROM xrd '
              . 'INNER JOIN ref ON ref.refid=xrd.refid '
              . 'INNER JOIN atm AS td ON td.atmid=xrd.xrddesc '
              . 'INNER JOIN atm AS tt ON tt.atmid=xrd.xrdtype '
              . 'INNER JOIN atm AS ts ON ts.atmid=xrd.xrdsuf '
              . 'WHERE dfnid=? ORDER BY xrdord ASC',
              undef,
              $dfn_id);
  if (ref($qr) eq 'ARRAY') {
    for my $xref (@$qr) {
      # Set children flag
      $has_children = 1;
      
      # Get cross-reference fields
      my $xr_trad = db_to_string($xref->[0]);
      my $xr_simp = db_to_string($xref->[1]);
      my $xr_pny  = $xref->[2];
      if (defined $xr_pny) {
        $xr_pny = db_to_string($xr_pny);
      }
      
      my $xr_desc = db_to_string($xref->[3]);
      my $xr_type = db_to_string($xref->[4]);
      my $xr_suff = db_to_string($xref->[5]);
      
      if (length($xr_desc) < 1) {
        $xr_desc = undef;
      }
      if (length($xr_type) < 1) {
        $xr_type = undef;
      }
      if (length($xr_suff) < 1) {
        $xr_suff = undef;
      }
      
      # Add this cross-reference element
      $xml = $xml . "\n          <n type=\"ref\"";
      $xml = $xml . sprintf(" trad=\"%s\"", _xml_att($xr_trad));
      $xml = $xml . sprintf(" simp=\"%s\"", _xml_att($xr_simp));
      if (defined $xr_pny) {
        $xml = $xml . sprintf(" pny=\"%s\"", _xml_att($xr_pny));
      }
      if (defined $xr_desc) {
        $xml = $xml . sprintf(" desc=\"%s\"", _xml_att($xr_desc));
      }
      if (defined $xr_type) {
        $xml = $xml . sprintf(" mode=\"%s\"", _xml_att($xr_type));
      }
      if (defined $xr_suff) {
        $xml = $xml . sprintf(" suff=\"%s\"", _xml_att($xr_suff));
      }
      $xml = $xml . "/>";
    }
  }
  
  # Closing element depends on whether there were any children
  if ($has_children) {
    $xml = $xml . "\n        </d>\n";
  } else {
    $xml = $xml . "</d>\n";
  }
  
  # Finish the workblock
  $dbc->finishWork;
  
  # Return finished XML
  return $xml;
}

# _xml_m(dbc, mpyid, trad, simp, pny, proper)
#
# Given a database connection, a major meaning ID, traditional and
# simplified readings, Pinyin (or undef), and proper set to 1 if this is
# a proper-name record or zero otherwise, with Unicode strings in
# Unicode format, generate and return the complete XML for the
# corresponding <m> element, including any annotations and definitions
# contained within, along with a line break at the end.
#
sub _xml_m {
  # Get and check parameters
  ($#_ == 5) or die "Wrong parameter count, stopped";
  
  my $dbc = shift;
  (ref($dbc) and $dbc->isa('Sino::DB')) or
    die "Wrong parameter type, stopped";
  
  my $mpy_id = shift;
  (not ref($mpy_id)) or die "Wrong parameter type, stopped";
  (int($mpy_id) == $mpy_id) or die "Wrong parameter type, stopped";
  $mpy_id = int($mpy_id);
  ($mpy_id >= 0) or die "Parameter out of range, stopped";
  
  my $mpy_trad = shift;
  (not ref($mpy_trad)) or die "Wrong parameter type, stopped";
  
  my $mpy_simp = shift;
  (not ref($mpy_simp)) or die "Wrong parameter type, stopped";
  
  my $mpy_pny = shift;
  if (defined $mpy_pny) {
    (not ref($mpy_pny)) or die "Wrong parameter type, stopped";
  }
  
  my $mpy_proper = shift;
  (not ref($mpy_proper)) or die "Wrong parameter type, stopped";
  
  # Start a read-only workblock
  my $dbh = $dbc->beginWork('r');
  my $qr;
  
  # Start the XML empty
  my $xml = '';
  
  # Flag indicating whether there are any child elements
  my $has_children = 0;
  
  # First comes the opening element
  if (defined $mpy_pny) {
    $xml = $xml . sprintf("      <m trad=\"%s\" simp=\"%s\" "
                                . "pny=\"%s\">",
                            _xml_att($mpy_trad),
                            _xml_att($mpy_simp),
                            _xml_att($mpy_pny));
  } else {
    $xml = $xml . sprintf("      <m trad=\"%s\" simp=\"%s\">",
                            _xml_att($mpy_trad),
                            _xml_att($mpy_simp));
  }
  
  # Measure-word annotations
  $qr = $dbh->selectall_arrayref(
                'SELECT reftrad, refsimp, refpny '
                . 'FROM msm '
                . 'INNER JOIN ref ON ref.refid = msm.refid '
                . 'WHERE mpyid=? ORDER BY msmord ASC',
                undef,
                $mpy_id);
  if (ref($qr) eq 'ARRAY') {
    for my $msw (@$qr) {
      # Set children flag
      $has_children = 1;
      
      # Get measure word fields
      my $msw_trad = db_to_string($msw->[0]);
      my $msw_simp = db_to_string($msw->[1]);
      my $msw_pny  = $msw->[2];
      if (defined $msw_pny) {
        $msw_pny = db_to_string($msw_pny);
      }
      
      # Add this measure-word/classifier element
      my $msw_fmt;
      if (defined $msw_pny) {
        $msw_fmt = "\n        <n type=\"msw\" trad=\"%s\" simp=\"%s\" "
                    . "pny=\"%s\"/>";
      } else {
        $msw_fmt = "\n        <n type=\"msw\" trad=\"%s\" simp=\"%s\">";
      }
      
      if (defined $msw_pny) {
        $xml = $xml . sprintf($msw_fmt,
                              _xml_att($msw_trad),
                              _xml_att($msw_simp),
                              _xml_att($msw_pny));
      } else {
        $xml = $xml . sprintf($msw_fmt,
                              _xml_att($msw_trad),
                              _xml_att($msw_simp));
      }
    }
  }
  
  # Alternate-pronunciation annotations
  $qr = $dbh->selectall_arrayref(
              'SELECT tctx.atmval, tcnd.atmval, apmpny '
              . 'FROM apm '
              . 'INNER JOIN atm AS tctx ON tctx.atmid=apm.apmctx '
              . 'INNER JOIN atm AS tcnd ON tcnd.atmid=apm.apmcond '
              . 'WHERE mpyid=? ORDER BY apmord ASC',
              undef,
              $mpy_id);
  if (ref($qr) eq 'ARRAY') {
    for my $pr (@$qr) {
      # Set children flag
      $has_children = 1;
      
      # Get pronunciation fields
      my $pr_ctx  = db_to_string($pr->[0]);
      my $pr_cond = db_to_string($pr->[1]);
      my $pr_pny  = db_to_string($pr->[2]);
      
      if (length($pr_ctx) < 1) {
        $pr_ctx = undef;
      }
      if (length($pr_cond) < 1) {
        $pr_cond = undef;
      }
      
      # Add this alternate pronunciation element
      $xml = $xml . "\n        <n type=\"alt\"";
      $xml = $xml . sprintf(" pny=\"%s\"", _xml_att($pr_pny));
      if (defined $pr_ctx) {
        $xml = $xml . sprintf(" ctx=\"%s\"", _xml_att($pr_ctx));
      }
      if (defined $pr_cond) {
        $xml = $xml . sprintf(" cond=\"%s\"", _xml_att($pr_cond));
      }
      $xml = $xml . "/>";
    }
  }
  
  # Cross-reference annotations
  $qr = $dbh->selectall_arrayref(
              'SELECT reftrad, refsimp, refpny, '
              . 'td.atmval, tt.atmval, ts.atmval '
              . 'FROM xrm '
              . 'INNER JOIN ref ON ref.refid=xrm.refid '
              . 'INNER JOIN atm AS td ON td.atmid=xrm.xrmdesc '
              . 'INNER JOIN atm AS tt ON tt.atmid=xrm.xrmtype '
              . 'INNER JOIN atm AS ts ON ts.atmid=xrm.xrmsuf '
              . 'WHERE mpyid=? ORDER BY xrmord ASC',
              undef,
              $mpy_id);
  if (ref($qr) eq 'ARRAY') {
    for my $xref (@$qr) {
      # Set children flag
      $has_children = 1;
      
      # Get cross-reference fields
      my $xr_trad = db_to_string($xref->[0]);
      my $xr_simp = db_to_string($xref->[1]);
      my $xr_pny  = $xref->[2];
      if (defined $xr_pny) {
        $xr_pny = db_to_string($xr_pny);
      }
      
      my $xr_desc = db_to_string($xref->[3]);
      my $xr_type = db_to_string($xref->[4]);
      my $xr_suff = db_to_string($xref->[5]);
      
      if (length($xr_desc) < 1) {
        $xr_desc = undef;
      }
      if (length($xr_type) < 1) {
        $xr_type = undef;
      }
      if (length($xr_suff) < 1) {
        $xr_suff = undef;
      }
      
      # Add this cross-reference element
      $xml = $xml . "\n        <n type=\"ref\"";
      $xml = $xml . sprintf(" trad=\"%s\"", _xml_att($xr_trad));
      $xml = $xml . sprintf(" simp=\"%s\"", _xml_att($xr_simp));
      if (defined $xr_pny) {
        $xml = $xml . sprintf(" pny=\"%s\"", _xml_att($xr_pny));
      }
      if (defined $xr_desc) {
        $xml = $xml . sprintf(" desc=\"%s\"", _xml_att($xr_desc));
      }
      if (defined $xr_type) {
        $xml = $xml . sprintf(" mode=\"%s\"", _xml_att($xr_type));
      }
      if (defined $xr_suff) {
        $xml = $xml . sprintf(" suff=\"%s\"", _xml_att($xr_suff));
      }
      $xml = $xml . "/>";
    }
  }
  
  # Get all definitions of this major meaning in an array where each
  # subarry has definition ID, definition sense, and definition gloss
  my @dfna;
  
  $qr = $dbh->selectall_arrayref(
                'SELECT dfnid, dfnsen, dfntext '
                . 'FROM dfn WHERE mpyid=? ORDER BY dfnord ASC',
                undef,
                $mpy_id);
  if (ref($qr) eq 'ARRAY') {
    for my $d (@$qr) {
      push @dfna, ([
        $d->[0], $d->[1], db_to_string($d->[2])
      ]);
    }
  }
  
  # If any definitions, add a line break here
  if ($#dfna >= 0) {
    $xml = $xml . "\n";
  }
  
  # Add each definition
  for my $drec (@dfna) {
    # Add the definition element
    $xml = $xml . _xml_d($dbc, $drec->[0], $drec->[1], $drec->[2]);
  }
  
  # Closing element depends on whether there were any children and
  # whether there were any definitions
  if ($#dfna >= 0) {
    $xml = $xml . "      </m>\n";
  } elsif ($has_children) {
    $xml = $xml . "\n      </m>\n";
  } else {
    $xml = $xml . "</m>\n";
  }
  
  # Finish the workblock
  $dbc->finishWork;
  
  # Return finished XML
  return $xml;
}

# Public procedure
#
sub words_xml {
  # Get and check parameters
  ($#_ == 1) or die "Wrong parameter count, stopped";
  
  my $dbc = shift;
  (ref($dbc) and $dbc->isa('Sino::DB')) or
    die "Wrong parameter type, stopped";
  
  my $word_ids = shift;
  (ref($word_ids) eq 'ARRAY') or die "Wrong parameter type, stopped";
  
  # Start a read-only workblock
  my $dbh = $dbc->beginWork('r');
  my $qr;
  
  # Start the XML empty
  my $xml = '';
  
  # Add the XML header
  $xml = $xml . "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
  $xml = $xml . "<words>\n";
  
  # Add each word
  for my $r_wordid (@$word_ids) {
    # Check ID type
    (not ref($r_wordid)) or die "Invalid word ID type, stopped";
    (int($r_wordid) == $r_wordid) or
      die "Invalid word ID type, stopped";
    
    my $word_id = int($r_wordid);
    ($word_id > 0) or die "Invalid word ID, stopped";
    
    # Get the basic word information
    my $word_level;
    my @wcs;
    
    $qr = $dbh->selectrow_arrayref(
                  'SELECT wordlevel FROM word WHERE wordid=?',
                  undef,
                  $word_id);
    (ref($qr) eq 'ARRAY') or
      die "Failed to find word $word_id, stopped";
    $word_level = $qr->[0];
    
    $qr = $dbh->selectall_arrayref(
                  'SELECT wclassname '
                  . 'FROM wc '
                  . 'INNER JOIN wclass ON wclass.wclassid=wc.wclassid '
                  . 'WHERE wc.wordid=? ORDER BY wcord ASC',
                  undef,
                  $word_id);
    if (ref($qr) eq 'ARRAY') {
      for my $q (@$qr) {
        push @wcs, (db_to_string($q->[0]));
      }
    }
    
    # Write the opening word element
    if ($#wcs >= 0) {
      $xml = $xml . sprintf("  <word recid=\"%d\" level=\"%d\" "
                              . "wcs=\"%s\">\n",
                            $word_id,
                            $word_level,
                            _xml_attl(\@wcs));
    } else {
      $xml = $xml . sprintf("  <word recid=\"%d\" level=\"%d\">\n",
                            $word_id,
                            $word_level);
    }
    
    # Get each reading, with each subarray storing the Han ID and the
    # Han rendering
    my @ra;
    
    $qr = $dbh->selectall_arrayref(
                  'SELECT hanid, hantrad '
                  . 'FROM han WHERE wordid=? ORDER BY hanord ASC',
                  undef,
                  $word_id);
    (ref($qr) eq 'ARRAY') or
      die "Word $word_id lacks readings, stopped";
    for my $r (@$qr) {
      push @ra, ([
        $r->[0], db_to_string($r->[1])
      ]);
    }
    
    # Add each reading
    for my $r (@ra) {
      # Get reading fields
      my $han_id   = $r->[0];
      my $han_trad = $r->[1];
      
      # Get any Pinyin for this reading
      my @pnys;
      
      $qr = $dbh->selectall_arrayref(
                    'SELECT pnytext '
                    . 'FROM pny WHERE hanid=? ORDER BY pnyord ASC',
                    undef,
                    $han_id);
      if (ref($qr) eq 'ARRAY') {
        for my $rec (@$qr) {
          push @pnys, (db_to_string($rec->[0]));
        }
      }
      
      # Write the opening reading element
      if ($#pnys >= 0) {
        $xml = $xml . sprintf("    <r han=\"%s\" pnys=\"%s\">",
                                _xml_att($han_trad),
                                _xml_attl(\@pnys));
      } else {
        $xml = $xml . sprintf("    <r han=\"%s\">",
                                _xml_att($han_trad));
      }
      
      # Get meanings for this reading, with each meaning subarray
      # storing the meaning ID, the traditional, simplified, and Pinyin,
      # and a flag indicating whether it's a proper name record
      my @ma;
      
      $qr = $dbh->selectall_arrayref(
                    'SELECT mpyid, reftrad, refsimp, refpny, mpyprop '
                    . 'FROM mpy '
                    . 'INNER JOIN ref ON ref.refid=mpy.refid '
                    . 'WHERE hanid=? ORDER BY mpyord ASC',
                    undef,
                    $han_id);
      if (ref($qr) eq 'ARRAY') {
        for my $rec (@$qr) {
          my $rec_pny = $rec->[3];
          if (defined $rec_pny) {
            $rec_pny = db_to_string($rec_pny);
          }
          push @ma, ([
            $rec->[0],
            db_to_string($rec->[1]),
            db_to_string($rec->[2]),
            $rec_pny,
            $rec->[4]
          ]);
        }
      }
      
      # If there are any meaning children, write a line break here
      if ($#ma >= 0) {
        $xml = $xml . "\n";
      }
      
      # Write each meaning child
      for my $m (@ma) {
        $xml = $xml . _xml_m(
                        $dbc,
                        $m->[0], $m->[1], $m->[2], $m->[3], $m->[4]);
      }
      
      # Write the closing reading element, depending on whether there
      # were any meaning children
      if ($#ma >= 0) {
        $xml = $xml . "    </r>\n";
      } else {
        $xml = $xml . "</r>\n";
      }
    }
    
    # Write the closing word element
    $xml = $xml . "  </word>\n";
  }
  
  # Finish the XML
  $xml = $xml . "</words>\n";
  
  # Finish the workblock
  $dbc->finishWork;
  
  # Return finished XML
  return $xml;
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
