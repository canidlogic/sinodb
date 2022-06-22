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
                  words_xml
                  keyword_query);

# Core dependencies
use Encode qw(decode encode);
use Unicode::Normalize;

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
        words_xml
        keyword_query);
  
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
  
  # Get matching words for a keyword query
  my $matches = keyword_query($dbc, 'husky AND "sled dog"', undef);
  for my $match (@$matches) {
    my $match_wordid    = $match->[0];
    my $match_wordlevel = $match->[1];
  }

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

=head2 Keyword query

This subsection documents the keyword query format and interpretation
used for the C<keyword_query> function.

=head3 Initial transformations

Keywords are insensitive to diacritics and to letter case, so before
parsing begins, the keyword string is decomposed into NFD, combining
diacritics from Unicode block [U+0300, U+036F] are dropped, the keyword
string is recomposed into NFC, and all ASCII uppercase letters are
translated into lowercase.  Additionally, the following normalizing
substitutions are performed to normalize variant punctuation:

                Variant form               |   Normalized form
  -----------------------------------------+---------------------
   Codepoint |         Description         | ASCII | Description
  ===========+=============================+=======+=============
    U+02BC   | Modifier letter apostrophe  | 0x27  | Apostrophe
    U+2019   | Right single quotation mark | 0x27  | Apostrophe      
  -----------+-----------------------------+-------+-------------
    U+2010   | Hyphen                      | 0x2D  | Hyphen-minus
    U+2011   | Non-breaking hyphen         | 0x2D  | Hyphen-minus
    U+2012   | Figure dash                 | 0x2D  | Hyphen-minus
    U+2013   | En dash                     | 0x2D  | Hyphen-minus
    U+2014   | Em dash                     | 0x2D  | Hyphen-minus
    U+2015   | Horizontal bar              | 0x2D  | Hyphen-minus

Finally, all sequences of whitespace are collapsed into single space
characters.  Only the following characters must remain after these
transformations, or the keyword string is invalid:

  <SP> a-z ' " - ( ) ? *

=head3 Syntax rules

Once the initial transformations described in the previous section have
been performed, the keyword query string must match the C<query>
production of the following syntax:

  query     := ( nq-phrase | q-block )+
  
  q-block   := <SP>* '"' q-phrase '"' <SP>*
  q-phrase  := <SP>* key ( <SP>+ key )* <SP>*
  
  nq-phrase := <SP>* nq-first nq-follow* <SP>*
  nq-first  := ( group | key )
  nq-follow := ( <SP>* group | <SP>+ key )
  group     := "(" query ")"
  
  key       := token ( <SP>* "-" <SP>* token )*
  token     := tk-core+ ( "'" tk-core+ )*
  tk-core   := { a-z ? * }

The most basic element here is a I<token>.  Tokens represent a search
token that must match at least one of the tokens within a gloss record.
Tokens are a sequence of one or more characters from the set including
lowercase ASCII letters, question mark, asterisk, and apostrophe, with
the restriction that apostrophe may only occur between two token
characters that are not themselves apostrophes (as shown in the syntax
above).

The question mark and asterisk are I<wildcards> that allow individual
search tokens to match multiple kinds of tokens within glosses.  The
question mark means that any single character in a gloss token can be
matched at this position.  The asterisk means that any sequence of zero
or more characters in a gloss token can be matched at this position.
You can combine these wildcards in sequence, for example C<dog???*> will
match C<dogsled> and C<doghouse> but not C<dogma> because there must be
at least three letters after the initial C<dog> to match.

On top of tokens are built I<keys>.  A key is a sequence of one or more
tokens, where tokens are separated from each other by hyphens.  (The
hyphens may also be surrounded by whitespace.)  Keys represent a
sequence of consecutive tokens that must appear in a gloss for the gloss
to match.  For example the C<sled-dog> will match the gloss C<Alaskan
sled dog>, but it will not match the gloss C<sled for a dog>.

The top-level syntax entity is a I<query>.  Queries contain a sequence
of one or more quoted key sequences, unquoted keys, and groups, as shown
in the syntax rules.  A I<group> is a recursively embedded subquery that
is surrounded by parentheses.  Groups are meaningful in the
interpretation of operators, which is described later.

Just because a query matches the syntax rules given in this section does
I<not> mean that it is a valid query.  There are higher-level
requirements beyond the syntax rules given here, which are explained in
subsequent sections here.

=head3 Wildcard normalization

Sequences of wildcards within tokens are normalized in the following
manner.  For each sequence of wildcards, count the total number of
question marks (if any), and also check whether there is at least one
asterisk.  The normalized form is a sequence of zero or more question
marks (matching the count of question marks), followed by a single
asterisk if there was at least one asterisk in the original sequence,
else followed by nothing.

For example, C<?**?*?**> normalizes to C<???*> which has an equivalent
meaning.

Normalization will be automatically be performed on each token during
the C<keyword_query> function.

=head3 Intermediate transform

Once a keyword query has been parsed according to the syntax rules given
earlier, and the wildcards have been normalized as described in the
previous section, the syntax tree is transformed into an intermediate
format described here.

The intermediate format of a query is an array of one or more
I<entities>.  Intermediate entities are either: (1) token sequences of
one or more tokens; (2) operators; or (3) subqueries.

Each quoted segment in the keyword query is transformed into a single
token sequence in the intermediate format containing the tokens in the
exact order they appear within the quotes.  The hyphenation of tokens
within quoted segments is irrelevant.  Therefore, for example,
C<"big sled-dog"> and C<"big-sled dog"> and C<"big sled dog"> all end up
as a token sequence of the three tokens C<big, sled, dog> in
intermediate form, with no difference in interpretation.

Each unquoted key in the keyword query is transformed either into a
token sequence or an operator.  If the unquoted key has just a single
token that matches C<and> C<or> or C<without> (case insensitive), then
the unquoted key is transformed into the corresponding operator.  In all
other cases, the unquoted key is transformed into a token sequence
matching the token(s) within the key.

Unlike within quoted segments, outside quoted segments hyphenation I<is>
meaningful.  C<big sled-dog> transforms into the token sequence C<big>
followed by the token sequence C<sled, dog>; C<big-sled dog> transforms
into the token sequence C<big, sled> followed by the token sequence
C<dog>; and C<big sled dog> transforms into the token sequence C<big>
followed by the token sequence C<sled> followed by the token sequence
C<dog>.

Quoting is for the most part an alternate notation that can always also
be equivalently represented as an unquoted, hyphenated token sequence,
except in one case.  The exception case is when you want search tokens
containing just the words C<and> C<or> or C<without>.  In this case, you
I<must> quote these words to prevent them from being transformed into
operators.  The following table gives some examples:

   Example query  |               Interpretation
  ================+=============================================
   sled and dog   | search "sled", operator "and", search "dog"
   sled "and" dog | search "sled", search "and", search "dog"
   sled and-dog   | search "sled", search "and dog"
   "sled and" dog | search "sled and", search "dog"
   sled - and dog | search "sled and", search "dog"
   "sled and dog" | search "sled and dog"
   sled-and-dog   | search "sled and dog"

Finally, each group within the keyword query is transformed into a
subquery in intermediate form.

The syntax of the transformed intermediate form must match C<i-query> in
the following:

  i-query   := content ( operator content+ )*
  content   := ( search | subquery )
  
  search    := <non-empty ARRAY OF i-token>
  operator  := ( <AND> | <OR> | <WITHOUT> )
  subquery  := <REFERENCE TO i-query>
  
  i-token   := itk-core+ ( "'" itk-core+ )*
  itk-core  := alpha | wildcards
  alpha     := { a-z }
  wildcards := ( "*" | ( ( "?" )+ ( "*" )? ) )

The main thing we have to be careful about here is the syntax rule that
operators may only occur when surrounding by search tokens or
subqueries, as shown in the rules above.  This is I<not> guaranteed by
the transforms we have done so far, and the search query is malformed if
this rule isn't followed.  Otherwise, the other rules should be upheld
provided that we've done all the transformations and normalizations
described so far.

=head3 Operator normalization

Before the query can be executed, the intermediate format arrived at in
the previous section has to be transformed again into the I<execution
format>.

The syntax rules of execution format are very similar to the syntax
rules of the intermediate format given in the last section:

  x-query   := ( search | x-op )
  x-op      := x-content operator x-content
  x-content := ( search | x-sub )
  
  search    := <non-empty ARRAY OF i-token>
  operator  := ( <AND> | <OR> | <WITHOUT> )
  x-sub     := <REFERENCE TO x-op>
  
  i-token   := itk-core+ ( "'" itk-core+ )*
  itk-core  := alpha | wildcards
  alpha     := { a-z }
  wildcards := ( "*" | ( ( "?" )+ ( "*" )? ) )

Everything that's different here is marked with an C<x-> prefix.  The
overall difference is that C<x-query> is much stricter than C<i-query>
from the previous section.  For C<x-query>, either the whole query is a
single search token array, or the query is an C<x-op>, which combines
two content entities together with an operator.  Content entities may
either be a search token array or a recursive C<x-op>.  This much
stricter final form is unambiguous with respect to how things get
combined with operators.

Transformation from intermediate format to execution format works
according to a recursive resolver algorithm.  The resolver algorithm
takes an C<i-query> from intermediate form as input and produces an
C<x-query> in execution form as output.  The first step in the resolver
algorithm is to scan to C<i-query> for subqueries and recursively apply
the resolver algorithm to any subqueries.  Each C<subquery> can then be
replaced either with a C<search> token, or an C<x-op> reference which
satisfies the C<x-sub> production.

After the first step of the resolver algorithm, we will have a sequence
of C<x-content> and C<operator> entities, where operators only occur
immediately between C<x-content> entities.  The second step of the
resolver algorithm is to look for places where two C<x-content> entities
are next to each other, and insert an C<AND> operator between them.
This means that when no operator is explicitly specified in the original
query, C<AND> is implicitly assumed.  Thus, C<sled dog> is an equivalent
query to C<sled and dog>.

After the second step of the resolver algorithm, our sequence of
C<x-content> and C<operator> entities will alternate between content and
operator, and the first and last entities will always be content
entities.  If we are left at this point with just a single C<x-content>
entity, then the result of the resolver algorithm is the search token or
C<x-op> contained within that C<x-content> entity.  Otherwise, we must
proceed further.

If we got to this point, there must be at least one operator in our
entity sequence.  We need to perform operator normalization until we are
left with only a single operator in the sequence.  Among the three
operators, C<WITHOUT> has the highest precedence, C<AND> is next, and
C<OR> has the lowest precedence.  To perform an operator normalization
step, find the highest precedence operator remaining in the entity
sequence.  If there are multiple operators with highest precedence,
choose the first (leftmost) one.  Take this operator and the surrounding
C<x-content> entities, combine them into an C<x-op>, and then replace
these three entities with a reference to that new C<x-op> in the entity
sequence.  Each of these operator normalization steps reduces the total
number of operators in the sequence by one while preserving the
alternating C<x-content> and C<operator> structure, so repeatedly
running this operation should eventually reduce the number of operators
in the sequence to one.

After the previous rounds of operator normalization, we will be left
with two C<x-content> entities combined with an C<operator>.  The result
of the resolver algorithm is then an C<x-op> containing those two
C<x-content> entities joined with an C<operator>.

=head3 Query execution

In order to understand query execution, we just need to understand how
sequences of search tokens select sets of records, and how operators can
combine two sets of records into one result set.  After this has been
established, it should be easy to understand how an C<x-query> as
defined in the previous section works.

Note that although all the query parsing and transformation steps so far
are implemented within this C<Sino::Op> module, the actual query
execution is I<not> implemented by this module.  Instead, this module
internally compiles the C<x-query> into a complex SQL SELECT query, and
SQLite will then perform the actual query, which is much more efficient.

Sequences of search tokens select sets of matching definition gloss
records.  Each gloss record in the C<dfn> table has already been parsed
into sequences of tokens and these parsing results then stored in the
C<tok> and C<tkm> tables by the C<tokenize.pl> script which should have
been run while building the Sino database.  For a sequence of search
tokens to match a gloss record, the tokenized form of the gloss record
must contain a subsequence of consecutive tokens that matches the search
tokens.  When the search tokens contain wildcards, it allows the search
tokens to match any gloss tokens that fit the criteria.

Therefore, for sequences of search tokens containing just a single
token, all gloss records will be selected that contain any token that
matches that search token.  For sequences of search tokens containing
multiple tokens, that sequence of tokens must appear within the gloss
token sequence without any additional tokens added in for the gloss
record to match.

Operators combine two gloss record sets A and B into one result set C by
performing a boolean operation.  The C<and> operator selects only those
gloss records that appear in both A and B; in other words, C is the
intersection of A C<and> B in this case.  The C<or> operator selects any
gloss records that appear in either A or B or both; in other words, C is
the union of A C<or> B in this case.  The C<without> operator selects
only those gloss records from A that do I<not> appear in B; in other
words, C is the subset of A that is C<without> any of the records from B
in this case.

For the results of the query, any word ID that has at least one gloss
included in the final results will be included.  Word IDs are sorted
first in ascending order of word level so that more frequently used
words come first, and second in ascending order of word ID.  The query
function allows for a subset of the results to be returned, and also
provides other facilities for enforcing limits.  See the function
documentation for further information.

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

=item B<keyword_query(dbc, query, attrib)>

Given a C<Sino::DB> database connection, a keyword query string, and
optionally a hash reference with query parameters, return an array
reference to matching records.

The query format is described in the "Keyword query" documentation given
near the top of this module.  Fatal errors occur if the given query
string can not be parsed.  The string should be in Unicode format, not
binary encoded.

The return is always an array reference.  If there were no matches, a
reference to an empty array will be returned.  Else, each record will be
a subarray reference that has two elements, the first being the word ID
and the second being the word level.  Records are sorted primarily by
ascending order of word level so that simpler, more frequent words come
first.  Within each word level, records are sorted in increasing order
of word ID.

The C<attrib> parameter can be set to C<undef> if you don't need any
special attributes.  Otherwise, it is a key/value map where unrecognized
attribute keys are ignored.

The C<max_query> attribute, if specified, must be set to an integer
value greater than zero.  If the length in codepoints of the C<query>
parameter is greater than this attribute value, then a fatal error will
occur preventing huge keyword strings.  If this attribute is not
specified, there is no upper limit on the total query length.

The C<max_depth> attribute, if specified, must be set to an integer
value greater than zero.  If set to one, then no groups with parentheses
are allowed.  If set to two, then there may be groups, but no groups
within groups.  If set to three, then there may be groups and groups
within groups, but no groups within groups within groups, and so forth.
If this attribute is not specified, there is no upper limit on the group
nesting depth.

The C<max_token> attribute, if specified, must be set to an integer
value greater than zero.  If set, then this is the maximum number of
search tokens allowed within the keyword query.  Within quoted entities,
each token is counted separately.  Within hyphenated token sequences,
each token is also counted separately.  If this attribute is not
specified, there is no upper limit on the number of search tokens.

(The C<max_query> C<max_depth> and C<max_token> attributes are intended
for putting limits on query complexity, which is useful when you are
allowing the general public to run queries over the Internet.)

The C<window_size> attribute, if specified, must be set to an integer
value greater than zero.  If set, then this is the maximum number of
records that will be returned.  If this attribute is not specified,
there is no upper limit on how many records can be returned.

The C<window_pos> attribute, if specified, must be set to an integer
value zero or greater.  If set, then this is the number of records that
are skipped at the beginning of the results.  If this attribute is not
specified, then it defaults to a value of zero, meaning no records are
skipped.

(The C<window_size> and C<window_pos> attributes when used together
allow for returning windows of results when there are potentially many
results.  Windowing is handled by the database engine, so it is fast.)

=cut

# _key_intermediate(str, max_query, max_depth, max_token)
#
# Given a keyword string, transform it into intermediate format and
# return the transformed results.
#
# The return value is an array reference to the intermediate format.
# Each array element is a hash that has an "etype" attribute that gives
# the type of entity and an "edata" attribute that has the entity value.
#
# For intermediate format, the "etype" is either "tseq" "op" or "subq".
# For "tseq" the "edata" is an array reference storing a sequence of one
# or more search tokens.  For "op" the "edata" is a string that either
# is "and" "or" or "without".  For "subq" the "edata" is a reference to
# another array in intermediate format storing a subquery.
#
# See the documentation at the top of this module for more about
# intermediate format.
#
# The max_query, max_depth, and max_token parameters must either be
# integers that are greater than zero or undef.  This correspond to
# query complexity limits, as explained in the documentation for the
# keyword_query() function interface.
#
sub _key_intermediate {
  # Get parameters
  ($#_ == 3) or die "Wrong number of parameters, stopped";
  
  my $str       = shift;
  my $max_query = shift;
  my $max_depth = shift;
  my $max_token = shift;
  
  (not ref($str)) or die "Wrong parameter type, stopped";
  
  for(my $i = 0; $i < 3; $i++) {
    my $val;
    if ($i == 0) {
      $val = $max_query;
      
    } elsif ($i == 1) {
      $val = $max_depth;
      
    } elsif ($i == 2) {
      $val = $max_token;
      
    } else {
      die "Unexpected";
    }
    
    (defined $val) or next;
    
    (not ref($val)) or die "Wrong parameter type, stopped";
    (int($val) == $val) or die "Wrong parameter type, stopped";
    
    $val = int($val);
    ($val > 0) or die "Parameter out of range, stopped";
    
    if ($i == 0) {
      $max_query = $val;
      
    } elsif ($i == 1) {
      $max_depth = $val;
      
    } elsif ($i == 2) {
      $max_token = $val;
      
    } else {
      die "Unexpected";
    }
  }
  
  # If maximum query length limit is defined, check it
  if (defined $max_query) {
    (length($str) <= $max_query) or
      die "Query length limited exceeded, stopped";
  }
  
  # Drop common diacritics from the string
  $str = NFD($str);
  $str =~ s/[\x{300}-\x{36f}]+//g;
  $str = NFC($str);
  
  # Translate uppercase letters to lowercase
  $str =~ tr/A-Z/a-z/;
  
  # Perform normalizing substitutions
  $str =~ s/[\x{2bc}\x{2019}]/'/g;
  $str =~ s/[\x{2010}-\x{2015}]/\-/g;
  $str =~ s/\s+/ /g;
  
  # Check that only valid characters remain
  ($str =~ /\A[ a-z'"\-\(\)\?\*]*\z/) or
    die "Query contains invalid characters, stopped";
  
  # Test that apostrophe is only used in allowed positions by creating
  # test copy of the string that has all apostrophes surrounded by
  # letters and wildcards replaced with control code 0x1A and seeing
  # whether any apostrophes remain after that
  my $test_copy = $str;
  $test_copy =~ s/([a-z\?\*])'([a-z\?\*])/$1\x{1a}$2/g;
  (not ($test_copy =~ /'/)) or
    die "Query has apostrophe in invalid position, stopped";
  
  # Drop spaces surrounding hyphens
  $str =~ s/\s*\-\s*/\-/g;
  
  # Test that hyphens, after dropping surrounding spaces, are only used
  # in allowed positions by creating a test copy of the string that has
  # all hyphens surrounded by letters and wildcards replaced with
  # control code 0x1A and seeing whether any hyphens remain after that
  $test_copy = $str;
  $test_copy =~ s/([a-z\?\*])\-([a-z\?\*])/$1\x{1a}$2/g;
  (not ($test_copy =~ /\-/)) or
    die "Query has hyphen in invalid position, stopped";
  
  # The double quotes and parentheses should stand by themselves in
  # tokens on the first tokenization pass, so add spaces around them
  $str =~ s/(["\(\)])/ $1 /g;
  
  # We can now perform the basic tokenization pass by splitting on
  # whitespace
  my @basic = split ' ', $str;
  
  # Go through the whole basic tokenization and make sure that
  # parenthesis tokens and quote tokens are properly paired, that
  # parentheses do not occur in quoted segments, that the maximum depth
  # does not exceed the max_depth limit if defined, that each token is
  # either a parenthesis, quote, or valid search token, that if the
  # max_token limit is defined, it is not exceeded, and finally apply
  # wildcard normalization to all tokens
  my $nest_depth = 1;
  my $dquote_active = 0;
  my $basic_count = 0;
  
  for my $token (@basic) {
    # Handle different token types
    if ($token eq '(') {
      # Opening parenthesis, so increase nesting depth
      $nest_depth++;
      
      # May not occur within quoted segments
      (not $dquote_active) or
        die "Parenthesis may not occur in quoted segments, stopped";
      
      # If limit is defined, check whether nesting depth has been
      # exceeded
      if (defined $max_depth) {
        ($nest_depth <= $max_depth) or
          die "Too many nested parentheses, stopped";
      }
      
    } elsif ($token eq ')') {
      # Closing parenthesis, so decrease nesting depth
      $nest_depth--;
      
      # May not occur within quoted segments
      (not $dquote_active) or
        die "Parenthesis may not occur in quoted segments, stopped";
      
      # If nesting depth has gone below 1, then there is a parenthesis
      # pairing problem
      ($nest_depth > 0) or
        die "Right parenthesis without matching left, stopped";
    
    } elsif ($token eq '"') {
      # Double quote, so toggle the dquote_active flag
      if ($dquote_active) {
        $dquote_active = 0;
      } else {
        $dquote_active = 1;
      }
    
    } elsif ($token =~
                /\A
                  [a-z\?\*]+
                  (?:'[a-z\?\*]+)*
                  (?:
                    \-
                    [a-z\?\*]+
                    (?:'[a-z\?\*]+)*
                  )*
                \z/x) {
      # Search token, so we first need to get the locations of any
      # wildcard sequences of more than one wildcard; each element in
      # this array is a subarray with the wildcard sequence, the
      # original offset, and the original length
      my @wcl;
      while ($token =~ /([\*\?]{2,})/g) {
        my $wcmatch = $1;
        my $wcpos   = pos($token) - length($wcmatch);
        push @wcl, ([
          $wcmatch, $wcpos, length($wcmatch)
        ]);
      }
      
      # Now go through and normalize each wildcard sequence
      for my $a (@wcl) {
        # Get the wildcard string
        my $wcstr = $a->[0];
        
        # Count the number of question marks
        my $qmc = 0;
        while ($wcstr =~ /\?/g) {
          $qmc++;
        }
        
        # Determine whether there is any asterisk
        my $ast = 0;
        if ($wcstr =~ /\*/) {
          $ast = 1;
        }
        
        # Reset string to empty
        $wcstr = '';
        
        # Add question marks
        for(my $j = 0; $j < $qmc; $j++) {
          $wcstr = $wcstr . '?';
        }
        
        # Add asterisk if there were any
        if ($ast) {
          $wcstr = $wcstr . '*';
        }
        
        # Shouldn't be empty
        (length($wcstr) > 0) or die "Unexpected";
        
        # Set the normalized wildcard string
        $a->[0] = $wcstr;
      }
      
      # Starting at end of token and working backward, replace all
      # wildcard sequences with the normalized version
      for(my $j = $#wcl; $j >= 0; $j--) {
        substr($token, $wcl[$j]->[1], $wcl[$j]->[2], $wcl[$j]->[0]);
      }
      
      # If limit defined, increase the token count once and then once
      # for every hyphen, checking that limit not exceeded
      if (defined $max_token) {
        $basic_count++;
        ($basic_count <= $max_token) or
          die "Too many search tokens, stopped";
        
        while ($token =~ /\-/g) {
          $basic_count++;
          ($basic_count <= $max_token) or
            die "Too many search tokens, stopped";
        }
      }
      
    } else {
      die "Unrecognized basic token type, stopped";
    }
  }
  (not $dquote_active) or
    die "Unpaired double quote, stopped";
  ($nest_depth == 1) or
    die "Left parenthesis without matching right, stopped";
  
  # If we got here, basic syntax of the query is verified and any
  # defined query complexity limits have been enforced; we now define a
  # query stack that allows us to handle recursive queries and start it
  # out with an empty array reference that represents the main query
  my @stack = ( [] );
  
  # Reset the dquote_active flag, which we will use for tracking whether
  # we are in a quoted segment
  $dquote_active = 0;
  
  # Now parse all the basic tokens
  for my $token (@basic) {
    # Handle different token types
    if ($token eq '(') {
      # Opening parenthesis, so quote must not be active (which we
      # checked earlier)
      (not $dquote_active) or die "Unexpected";
      
      # Push an empty array onto the stack to represent the new subquery
      push @stack, ( [] );
      
    } elsif ($token eq ')') {
      # Closing parenthesis, so quote must not be active (which we
      # checked earlier)
      (not $dquote_active) or die "Unexpected";
      
      # Pop the subquery array from the stack
      my $sqa = pop @stack;
      
      # Make sure subquery array is not empty
      (scalar(@$sqa) > 0) or die "Empty subquery, stopped";
      
      # Make sure last element of subquery is not an operator
      (not ($sqa->[-1]->{'etype'} eq 'op')) or
        die "Subquery ends with operator, stopped";
      
      # Add subquery as a subq entity to the end of the query array on
      # top of the stack
      push @{$stack[-1]}, ({
        etype => 'subq',
        edata => $sqa
      });
    
    } elsif ($token eq '"') {
      # Double quote, so toggle state
      if ($dquote_active) {
        # Quote was active, now closing; clear quote flag
        $dquote_active = 0;
        
        # Make sure the array on top of the stack is not empty
        (scalar(@{$stack[-1]}) > 0) or
          die "Empty quoted segment, stopped";
        
        # Pop the token list entity
        my $tle = pop @stack;
        
        # Add a tseq entity to the end of the query array on top of the
        # stack
        push @{$stack[-1]}, ({
          etype => 'tseq',
          edata => $tle
        });
      
      } else {
        # Quote was not active, now opening; set quote flag
        $dquote_active = 1;
        
        # Push an empty array on top of the stack which will get all the
        # tokens within the quotes
        push @stack, ( [] );
      }
      
    } else {
      # Search token, first check whether we are inside a quote
      if ($dquote_active) {
        # We are inside a quote, so we just push each token onto the
        # array on top of the stack, treated hyphenated elements as
        # individual tokens
        push @{$stack[-1]}, (split /\-/, $token);
        
      } else {
        # We are outside of a quote, so distinguish between operators
        # and search tokens
        if (($token eq 'and'    ) or
            ($token eq 'or'     ) or
            ($token eq 'without')) {
          # We have an operator, so first make sure that this is not the
          # first entity in the current query and that the previous
          # entity in the current query was not also an operator
          (scalar(@{$stack[-1]}) > 0) or
            die "Operator may not begin a (sub)query, stopped";
          ($stack[-1]->[-1]->{'etype'} ne 'op') or
            die "Consecutive operators not allowed, stopped";
          
          # Add the operator entity to the current query
          push @{$stack[-1]}, ({
            etype => 'op',
            edata => $token
          });
        
        } else {
          # We don't have an operator, so first parse this search key
          # into a token sequence
          my @tkseq = split /\-/, $token;
          
          # Add a tseq entity to the end of the query array on top of
          # the stack
          push @{$stack[-1]}, ({
            etype => 'tseq',
            edata => \@tkseq
          });
        }
      }
    }
  }
  
  # Exactly one element should remain on stack
  ($#stack == 0) or die "Unexpected";
  
  # Get the resulting query array from the stack
  my $result = pop @stack;
  
  # Make sure query array is not empty
  (scalar(@$result) > 0) or die "Empty query, stopped";
  
  # Make sure last element of query is not an operator
  (not ($result->[-1]->{'etype'} eq 'op')) or
    die "Query ends with operator, stopped";
  
  # Return result
  return $result;
}

# @@TODO:
sub _test_print {
  my $test = shift;
  for my $a (@$test) {
    if ($a->{'etype'} eq 'op') {
      printf "OPERATOR %s\n", $a->{'edata'};
      
    } elsif ($a->{'etype'} eq 'tseq') {
      print "SEARCH (";
      my $first = 1;
      for my $b (@{$a->{'edata'}}) {
        if ($first) {
          $first = 0;
        } else {
          print ", ";
        }
        print $b;
      }
      print ")\n";
      
    } elsif ($a->{'etype'} eq 'subq') {
      print "BEGIN SUBQUERY\n";
      _test_print($a->{'edata'});
      print "END SUBQUERY\n";
      
    } else {
      die "Unexpected";
    }
  }
}

sub keyword_query {
  # @@TODO:
  my $str = shift;
  my $test = _key_intermediate($str, undef, undef, undef);
  _test_print($test);
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
