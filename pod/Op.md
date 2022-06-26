# NAME

Sino::Op - Sino database operations module.

# SYNOPSIS

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
          keyword_query
          han_query);
    
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
    
    # Enter a remapped Han reading
    my $han_id = enter_han($dbc, $word_id, $remapped_reading, 1);
    
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
    
    # Get matching words for a Han query
    my $matches = han_query($dbc, $han, undef);
    for my $match (@$matches) {
      my $match_wordid    = $match->[0];
      my $match_wordlevel = $match->[1];
    }

# DESCRIPTION

Provides various database operation functions.  See the documentation of
the individual functions for further information.

## XML description format

This subsection documents the XML format used in the `words_xml`
function.

The overall structure of the document is summarized as follows:

    <?xml version="1.0" encoding="UTF-8"?>
    <words>
      <word recid="5" level="2" wcs="..., ..., ...">
        <r han="..." pnys="..., ..., ..." type="remap">
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

An _attribute list_ is an attribute value containing a sequence of one
or more strings, where the separators between each string is a comma and
a space.  These lists are represented by `..., ..., ...` in the example
above.

For any element shown in the example above where there are three
attributes `trad` `simp` and `pny` the following rules apply.
`trad` and `simp` are required, giving the traditional reading and
the simplified reading.  If both traditional and simplified readings are
the same, both attributes are still required and both should have the
same value.  The `pny` attribute is optional.  If present, it must
contain a normalized Pinyin pronunciation.

The top-level entity is a container element `words` that contains
individual `word` elements, which are each completely separate from
each other.  Allowing multiple word elements allows for multiple word
queries in one transaction, which is more efficient.

Each `word` element is required to have a `recid` attribute and a
`level` attribute which identify the unique word ID within the Sino
database and the vocabulary level 1-9 associated with the word.
Optionally, word elements may have a `wcs` element, which is a list
attribute of one or more word class names that apply to this word.  The
word classes, if present, come from the TOCFL data.

Word elements are also containers for one or more `r` elements, which
define the individual readings of the word.  Each reading element must
have a `han` attribute, which defines one specific Han reading of the
word.  Each reading element may optionally have a `pnys` attribute,
which is an attribute list of one or more normalized Pinyin renderings
of this reading element.  The `han` attribute is either from TOCFL or
COCT, except for level 9, where it is from CC-CEDICT.  The `pnys`
attribute if present is from TOCFL.  There is also an optional `type`
attribute that can be set to `remap` or `core`, with `core` being the
default.  If set to `remap`, it means the reading wasn't present in the
original TOCFL/COCT, but was added to prevent an entry solely containing
a cross-reference.  See `remap.pl` for further information.

Each reading element is also a container for zero or more `m` elements,
which define the major meanings of the reading.  Each `m` element has
required `trad` and `simp` attributes, as well as an optional `pny`
attribute.  There is also an optional `type` attribute which may have
the value `common` or `proper`, indicating meanings that CC-CEDICT
associates as not proper names or proper names, respectively; if not
specified, `common` is assumed.  The `trad` and `simp` are according
to CC-CEDICT.  The `han` of the parent `r` element does _not_
necessarily match `trad`.  Sometimes it might match `simp` instead, or
it could even match neither.  `pny` is according to CC-CEDICT, so it
favors mainland pronunications.

Within each major meaning element is a sequence of zero or more
definition elements `d`.  Each definition element must have a `sense`
attribute that gives a sense number, as well as a `gloss` attribute
that stores the actual gloss.

Both `m` and `d` elements may contain sequences of zero or more `n`
elements, which represent annotations on their parent element.
Annotation elements must have a `type` attribute with a value either
`msw` `alt` or `ref` declaring the annotation type as either a
measure word (classifier), alternate pronunciation, or cross-reference.
There may be multiple annotations of each type.

Measure-word annotations have the required `trad` and `simp` 
attributes and the optional `pny` attribute to associate a measure word
either with the whole meaning element or with a specific gloss.

Alternate-pronunciation annotations have optional `ctx` and `cond`
attributes defining the context in which the alternate pronunciation is
used and any special conditions or meanings attached to the alternate
pronunication.  All such annotations of course also have a required
`pny` attribute defining the normalized Pinyin of the alternate
pronunication.  Since these annotations comes from CC-CEDICT, Taiwanese
pronunications are considered an "alternate" pronunication.  These
annotations associate the alternate pronunication either with the whole
meaning element or with a specific gloss.

Cross-reference annotations have optional `mode` `desc` and `suff`
attributes defining a cross-reference mode, a descriptor modifier of
that mode, and a suffix with more information about the cross-reference.
Cross-reference annotations must have `trad` and `simp` attributes and
optionally a `pny` attribute.  These annotations associate the
cross-reference either with the whole meaning element or with a specific
gloss.

Definition elements may also contain zero or more `c` elements, which
represent citations within the gloss.  Each citation must have `off`
and `len` attributes that define the codepoint offset and codepoint
length of the citation within the parent element's `gloss` attribute,
as well as require `trad` and `simp` attributes and an optional `pny`
field.  Citations will not overlap within the gloss, and each must
select a valid range of characters within the gloss.

## Keyword query

This subsection documents the keyword query format and interpretation
used for the `keyword_query` function.

### Initial transformations

Keywords are insensitive to diacritics and to letter case, so before
parsing begins, the keyword string is decomposed into NFD, combining
diacritics from Unicode block \[U+0300, U+036F\] are dropped, the keyword
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

### Syntax rules

Once the initial transformations described in the previous section have
been performed, the keyword query string must match the `query`
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

The most basic element here is a _token_.  Tokens represent a search
token that must match at least one of the tokens within a gloss record.
Tokens are a sequence of one or more characters from the set including
lowercase ASCII letters, question mark, asterisk, and apostrophe, with
the restriction that apostrophe may only occur between two token
characters that are not themselves apostrophes (as shown in the syntax
above).

The question mark and asterisk are _wildcards_ that allow individual
search tokens to match multiple kinds of tokens within glosses.  The
question mark means that any single character in a gloss token can be
matched at this position.  The asterisk means that any sequence of zero
or more characters in a gloss token can be matched at this position.
You can combine these wildcards in sequence, for example `dog???*` will
match `dogsled` and `doghouse` but not `dogma` because there must be
at least three letters after the initial `dog` to match.

On top of tokens are built _keys_.  A key is a sequence of one or more
tokens, where tokens are separated from each other by hyphens.  (The
hyphens may also be surrounded by whitespace.)  Keys represent a
sequence of consecutive tokens that must appear in a gloss for the gloss
to match.  For example the `sled-dog` will match the gloss `Alaskan
sled dog`, but it will not match the gloss `sled for a dog`.

The top-level syntax entity is a _query_.  Queries contain a sequence
of one or more quoted key sequences, unquoted keys, and groups, as shown
in the syntax rules.  A _group_ is a recursively embedded subquery that
is surrounded by parentheses.  Groups are meaningful in the
interpretation of operators, which is described later.

Just because a query matches the syntax rules given in this section does
_not_ mean that it is a valid query.  There are higher-level
requirements beyond the syntax rules given here, which are explained in
subsequent sections here.

### Wildcard normalization

Sequences of wildcards within tokens are normalized in the following
manner.  For each sequence of wildcards, count the total number of
question marks (if any), and also check whether there is at least one
asterisk.  The normalized form is a sequence of zero or more question
marks (matching the count of question marks), followed by a single
asterisk if there was at least one asterisk in the original sequence,
else followed by nothing.

For example, `?**?*?**` normalizes to `???*` which has an equivalent
meaning.

Normalization will be automatically be performed on each token during
the `keyword_query` function.

### Intermediate transform

Once a keyword query has been parsed according to the syntax rules given
earlier, and the wildcards have been normalized as described in the
previous section, the syntax tree is transformed into an intermediate
format described here.

The intermediate format of a query is an array of one or more
_entities_.  Intermediate entities are either: (1) token sequences of
one or more tokens; (2) operators; or (3) subqueries.

Each quoted segment in the keyword query is transformed into a single
token sequence in the intermediate format containing the tokens in the
exact order they appear within the quotes.  The hyphenation of tokens
within quoted segments is irrelevant.  Therefore, for example,
`"big sled-dog"` and `"big-sled dog"` and `"big sled dog"` all end up
as a token sequence of the three tokens `big, sled, dog` in
intermediate form, with no difference in interpretation.

Each unquoted key in the keyword query is transformed either into a
token sequence or an operator.  If the unquoted key has just a single
token that matches `and` `or` or `without` (case insensitive), then
the unquoted key is transformed into the corresponding operator.  In all
other cases, the unquoted key is transformed into a token sequence
matching the token(s) within the key.

Unlike within quoted segments, outside quoted segments hyphenation _is_
meaningful.  `big sled-dog` transforms into the token sequence `big`
followed by the token sequence `sled, dog`; `big-sled dog` transforms
into the token sequence `big, sled` followed by the token sequence
`dog`; and `big sled dog` transforms into the token sequence `big`
followed by the token sequence `sled` followed by the token sequence
`dog`.

Quoting is for the most part an alternate notation that can always also
be equivalently represented as an unquoted, hyphenated token sequence,
except in one case.  The exception case is when you want search tokens
containing just the words `and` `or` or `without`.  In this case, you
_must_ quote these words to prevent them from being transformed into
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

The syntax of the transformed intermediate form must match `i-query` in
the following:

    i-query   := content+ ( operator content+ )*
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
subqueries, as shown in the rules above.  This is _not_ guaranteed by
the transforms we have done so far, and the search query is malformed if
this rule isn't followed.  Otherwise, the other rules should be upheld
provided that we've done all the transformations and normalizations
described so far.

### Operator normalization

Before the query can be executed, the intermediate format arrived at in
the previous section has to be transformed again into the _execution
format_.

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

Everything that's different here is marked with an `x-` prefix.  The
overall difference is that `x-query` is much stricter than `i-query`
from the previous section.  For `x-query`, either the whole query is a
single search token array, or the query is an `x-op`, which combines
two content entities together with an operator.  Content entities may
either be a search token array or a recursive `x-op`.  This much
stricter final form is unambiguous with respect to how things get
combined with operators.

Transformation from intermediate format to execution format works
according to a recursive resolver algorithm.  The resolver algorithm
takes an `i-query` from intermediate form as input and produces an
`x-query` in execution form as output.  The first step in the resolver
algorithm is to scan to `i-query` for subqueries and recursively apply
the resolver algorithm to any subqueries.  Each `subquery` can then be
replaced either with a `search` token, or an `x-op` reference which
satisfies the `x-sub` production.

After the first step of the resolver algorithm, we will have a sequence
of `x-content` and `operator` entities, where operators only occur
immediately between `x-content` entities.  The second step of the
resolver algorithm is to look for places where two `x-content` entities
are next to each other, and insert an `AND` operator between them.
This means that when no operator is explicitly specified in the original
query, `AND` is implicitly assumed.  Thus, `sled dog` is an equivalent
query to `sled and dog`.

After the second step of the resolver algorithm, our sequence of
`x-content` and `operator` entities will alternate between content and
operator, and the first and last entities will always be content
entities.  If we are left at this point with just a single `x-content`
entity, then the result of the resolver algorithm is the search token or
`x-op` contained within that `x-content` entity.  Otherwise, we must
proceed further.

If we got to this point, there must be at least one operator in our
entity sequence.  We need to perform operator normalization until we are
left with only a single operator in the sequence.  Among the three
operators, `WITHOUT` has the highest precedence, `AND` is next, and
`OR` has the lowest precedence.  To perform an operator normalization
step, find the highest precedence operator remaining in the entity
sequence.  If there are multiple operators with highest precedence,
choose the first (leftmost) one.  Take this operator and the surrounding
`x-content` entities, combine them into an `x-op`, and then replace
these three entities with a reference to that new `x-op` in the entity
sequence.  Each of these operator normalization steps reduces the total
number of operators in the sequence by one while preserving the
alternating `x-content` and `operator` structure, so repeatedly
running this operation should eventually reduce the number of operators
in the sequence to one.

After the previous rounds of operator normalization, we will be left
with two `x-content` entities combined with an `operator`.  The result
of the resolver algorithm is then an `x-op` containing those two
`x-content` entities joined with an `operator`.

### Query execution

In order to understand query execution, we just need to understand how
sequences of search tokens select sets of records, and how operators can
combine two sets of records into one result set.  After this has been
established, it should be easy to understand how an `x-query` as
defined in the previous section works.

Note that although all the query parsing and transformation steps so far
are implemented within this `Sino::Op` module, the actual query
execution is _not_ implemented by this module.  Instead, this module
internally compiles the `x-query` into a complex SQL SELECT query, and
SQLite will then perform the actual query, which is much more efficient.

Sequences of search tokens select sets of matching definition gloss
records.  Each gloss record in the `dfn` table has already been parsed
into sequences of tokens and these parsing results then stored in the
`tok` and `tkm` tables by the `tokenize.pl` script which should have
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
performing a boolean operation.  The `and` operator selects only those
gloss records that appear in both A and B; in other words, C is the
intersection of A `and` B in this case.  The `or` operator selects any
gloss records that appear in either A or B or both; in other words, C is
the union of A `or` B in this case.  The `without` operator selects
only those gloss records from A that do _not_ appear in B; in other
words, C is the subset of A that is `without` any of the records from B
in this case.

For the results of the query, any word ID that has at least one gloss
included in the final results will be included.  Word IDs are sorted
first in ascending order of word level so that more frequently used
words come first, and second in ascending order of word ID.  The query
function allows for a subset of the results to be returned, and also
provides other facilities for enforcing limits.  See the function
documentation for further information.

# FUNCTIONS

- **string\_to\_db($str)**

    Get a binary UTF-8 string copy of a given Unicode string.

    Since `Sino::DB` sets SQLite to operate in binary string mode, you must
    encode any Unicode string into a binary string with this function before
    you can pass it through to SQLite.

    If you know the string only contains US-ASCII, this function is
    unnecessary.

- **db\_to\_string($str)**

    Get a Unicode string copy of a given binary UTF-8 string.

    Since `Sino::DB` sets SQLite to operate in binary string mode, you must
    decode any binary UTF-8 string received from SQLite with this function
    before you can use it as a Unicode string in Perl.

    If you know the string only contains US-ASCII, this function is
    unnecessary.

- **wordid\_new(dbc)**

    Given a `Sino::DB` database connection, get a new word ID to use.  If
    no words are defined yet, the new word ID will be 1.  Otherwise, it will
    be one greater than the maximum word ID currently in use.

    **Caution:** A race will occur between the time you get the new ID and
    the time you attempt to use the new ID, unless you call this function in
    the same work block that defines the new word.

- **enter\_han(dbc, wordid, hantrad \[, remap\])**

    Given a `Sino::DB` database connection, a word ID, and a Han
    traditional character rendering, add it as a Han reading of the given
    word ID unless it is already present in the han table.  In all cases,
    return a `hanid` corresponding to this reading in the han table.

    Fatal errors occur if the given word ID is not in the word table, or if
    the Han traditional character rendering is already used for a different
    word ID.

    `hantrad` should be a Unicode string, not a binary string.  A r/w work
    block will start in this function, so don't call this function within a
    read-only block.

    If a new Han record is added, its `hantype` is set to zero, indicating
    it is not a remap record.  However, if you include an additional,
    optional parameter and set it to 1, then the record will be added as a
    remap, but only if it doesn't exist yet.

- **enter\_wordclass(dbc, wordid, wclassname)**

    Given a `Sino::DB` database connection, a word ID, and the name of a
    word class, add that word class to the given word ID unless it is
    already present in the wc table.

    `wclassname` is the ASCII name of the word class.  This must be in the
    wclass table already or a fatal error occurs.  Also, the given word ID
    must already be in the word table or a fatal error occurs.

    A r/w work block will start in this function, so don't call this
    function within a read-only block.
    \#
    \# This function does not check that the given wordid actually exists in
    \# the word table, and it does not check that wclassid actually is a
    \# valid foreign key.

- **enter\_pinyin(dbc, hanid, pny)**

    Given a `Sino::DB` database connection, a Han ID, and a Pinyin reading,
    add it as a Pinyin reading of the given Han ID unless it is already
    present in the pny table.

    `pny` should be a Unicode string, not a binary string.  It must pass
    the `pinyin_split()` function in `Sino::Util` to check for validity or
    a fatal error occurs.  The given Han ID must exist in the han table or a
    fatal error occurs.  A r/w work block will start in this function, so
    don't call this function within a read-only block.

- **enter\_ref(dbc, trad, simp, pinyin)**

    Given a `Sino::DB` database connection, a traditional Han reading, a
    simplified Han reading, and optionally a Pinyin reading, enter this
    reference in the ref table if not already present, and in all cases
    return a `refid` corresponding to the given reference. 

    `trad` `simp` and `pinyin` should be Unicode strings, not a binary
    strings.  `pinyin` may also be `undef` for cases where a Pinyin 
    reading isn't part of the reference, or where a main entry has Pinyin
    that doesn't normalize.  If traditional and simplified readings are the
    same, pass the same string for both parameters.  Traditional and
    simplified readings may only include characters from the core CJK
    Unicode block.  The given `pinyin` must pass `pinyin_split` in
    `Sino::Util` to verify that it is normalized (unless it is `undef`).

    A r/w work block will start in this function, so don't call this
    function within a read-only block.

- **enter\_atom(dbc, str)**

    Given a `Sino::DB` database connection and a string, enter the string
    in the atom table if not already present and in all cases return a
    `atmid` corresponding to the appropriate atom record.

    `str` should be a Unicode string, not a binary string.  It may contain
    any Unicode codepoints except for ASCII control codes and surrogates.
    (Supplemental codepoints are OK.)  An empty string _is_ an acceptable
    atom string.

    A r/w work block will start in this function, so don't call this
    function within a read-only block.

- **words\_xml(dbc, ids)**

    Given a `Sino::DB` database connection and a reference to an array
    storing one or more word IDs, return a structured XML result containing
    all the information about those words from the database.  See the
    documentation at the top of this module for the specific XML format.

    The returned XML text is a Unicode string that may include Unicode
    codepoints.  If you need it in a binary string context, you should use
    UTF-8 encoding, as that is what is declared in the XML header.

- **keyword\_query(dbc, query, attrib)**

    Given a `Sino::DB` database connection, a keyword query string, and
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

    The `attrib` parameter can be set to `undef` if you don't need any
    special attributes.  Otherwise, it is a key/value map where unrecognized
    attribute keys are ignored.

    The `max_query` attribute, if specified, must be set to an integer
    value greater than zero.  If the length in codepoints of the `query`
    parameter is greater than this attribute value, then a fatal error will
    occur preventing huge keyword strings.  If this attribute is not
    specified, there is no upper limit on the total query length.

    The `max_depth` attribute, if specified, must be set to an integer
    value greater than zero.  If set to one, then no groups with parentheses
    are allowed.  If set to two, then there may be groups, but no groups
    within groups.  If set to three, then there may be groups and groups
    within groups, but no groups within groups within groups, and so forth.
    If this attribute is not specified, there is no upper limit on the group
    nesting depth.

    The `max_token` attribute, if specified, must be set to an integer
    value greater than zero.  If set, then this is the maximum number of
    search tokens allowed within the keyword query.  Within quoted entities,
    each token is counted separately.  Within hyphenated token sequences,
    each token is also counted separately.  If this attribute is not
    specified, there is no upper limit on the number of search tokens.

    (The `max_query` `max_depth` and `max_token` attributes are intended
    for putting limits on query complexity, which is useful when you are
    allowing the general public to run queries over the Internet.)

    The `window_size` attribute, if specified, must be set to an integer
    value greater than zero.  If set, then this is the maximum number of
    records that will be returned.  If this attribute is not specified,
    there is no upper limit on how many records can be returned, and the
    `window_pos` is ignored.

    The `window_pos` attribute, if specified, must be set to an integer
    value zero or greater.  If set, then this is the number of records that
    are skipped at the beginning of the results.  If this attribute is not
    specified, then it defaults to a value of zero, meaning no records are
    skipped.  This attribute is ignored if `window_size` is not set.

    (The `window_size` and `window_pos` attributes when used together
    allow for returning windows of results when there are potentially many
    results.  Windowing is handled by the database engine, so it is fast.)

- **han\_query(dbc, query, attrib)**

    Given a `Sino::DB` database connection, a Han query string, and
    optionally a hash reference with query parameters, return an array
    reference to matching records.

    The query is a sequence of one or more Han characters and wildcards,
    optionally surrounded by whitespace.  The wildcards allowed are `*`
    meaning match any sequence of zero or more Han characters and `?`
    meaning match any one Han character.  These can be combined in a
    sequence, such that `???*` means match any sequence of three or more
    Han characters, for example.  Wildcard normalization will be performed
    by this function, in the same manner as for `keyword_query`.

    Han character matching uses "Han normalization" such that simplified and
    traditional variants of the same character will match each other.  You
    can specify strict matching only with an attribute (see below).

    The query string must be Unicode encoded.  Do not pass a binary-encoded
    string.

    The return is always an array reference.  If there were no matches, a
    reference to an empty array will be returned.  Else, each record will be
    a subarray reference that has two elements, the first being the word ID
    and the second being the word level.  Records are sorted primarily by
    ascending order of word level so that simpler, more frequent words come
    first.  Within each word level, records are sorted in increasing order
    of word ID.

    The `attrib` parameter can be set to `undef` if you don't need any
    special attributes.  Otherwise, it is a key/value map where unrecognized
    attribute keys are ignored.

    The `match_style` attribute, if specified, must be set to `strict` or
    `loose`.  If not specified, `loose` is the default.  With loose
    matching, "Han normalization" is used so that simplified and traditional
    variants will match.  With strict matching, no Han normalization is
    performed, such that characters will only match if exactly the same.

    The `window_size` attribute, if specified, must be set to an integer
    value greater than zero.  If set, then this is the maximum number of
    records that will be returned.  If this attribute is not specified,
    there is no upper limit on how many records can be returned, and the
    `window_pos` is ignored.

    The `window_pos` attribute, if specified, must be set to an integer
    value zero or greater.  If set, then this is the number of records that
    are skipped at the beginning of the results.  If this attribute is not
    specified, then it defaults to a value of zero, meaning no records are
    skipped.  This attribute is ignored if `window_size` is not set.

    (The `window_size` and `window_pos` attributes when used together
    allow for returning windows of results when there are potentially many
    results.  Windowing is handled by the database engine, so it is fast.)

# AUTHOR

Noah Johnson, `noah.johnson@loupmail.com`

# COPYRIGHT AND LICENSE

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
