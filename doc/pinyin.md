# Pinyin notes

This document describes standard Pinyin, the specific Pinyin formats used in the TOCFL dataset and CC-CEDICT, and conversion processes between those representations.

## Standard Pinyin transcription

Pinyin transcribes syllables.  Syllables have the following structure:

1. Initial consonant
2. Vowel
3. Final consonant
4. Erhua inflection

In spoken Mandarin, all of these components are optional, including the vowel.  However, Pinyin transcription always requires a vowel and usually requires an initial consonant.  When a vowel is not present in spoken Mandarin, a dummy `i` vowel is used in Pinyin.  When an initial consonant is not present in spoken Mandarin, an alternate form of the vowel is used that has a fake initial consonant, or, failing that, an apostrophe is used in place of the initial consonant.  However, the apostrophe is dropped when it would come as the first symbol in a word.  This dropped apostrophe at the start of a word is the only situation in which the initial consonant is not present.

> Note: Both TOCFL and CC-CEDICT have transcription irregularities such that these rules are not always followed.  These irregularities will be discussed later in the notes about those specific formats.

Mandarin never has more than one initial consonant.  All consonants may be used as initial consonants except for `ng`.  The final consonant is optional, and Mandarin never has more than one final consonant.  Only `n` `ng` and `r` may be used as final consonants.  When `r` is used as a final consonant, the vowel must be `e`, and no initial consonant is allowed when the final consonant is `r`.  (Pinyin transcription will follow the rules given earlier and use an apostrophe as the initial consonant in this case, dropping this apostrophe if it would be the first symbol in the word.)

The _erhua inflection_ is an optional `r` that may be added to the end of the syllable.  This `r` may appear _in addition to_ a final consonant, though it is not acceptable to have an erhua inflection when the final consonant is already `r`.  It is acceptable to have an erhua inflection without any final consonant.  When `r` appears at the end of a Pinyin syllable, it is always an erhua inflection, except when the vowel is `e` and there is no initial consonant (or an apostrophe in place of an initial consonant), in which case it is an `r` final consonant, as described earlier.

### Consonants

Mandarin consonants are transcribed into Pinyin as follows.  Where pairs of consonants are given, the first in the pair is aspirated and the second is unaspirated.

               | Labial | Alveolar | Retroflex | Alveolo-palatal | Velar
    ===========+========+==========+===========+=================+=======
     Plosive   | p | b  |  t |  d  |           |                 | k | g
    -----------+--------+----------+-----------+-----------------+-------
     Nasal     |   m    |    n     |           |                 |  ng
    -----------+--------+----------+-----------+-----------------+-------
     Affricate |        |  c |  z  |  ch | zh  |    q   |   j    |
    -----------+--------+----------+-----------+-----------------+-------
     Fricative |   f    |    s     |    sh     |        x        |   h
    -----------+--------+----------+-----------+-----------------+-------
     Liquid    |        |    l     |     r     |                 |
    -----------+--------+----------+-----------+-----------------+-------

Each of these consonants, except `ng`, can be used as an initial consonant in a syllable.  Only `n` `ng` and `r` can be used as a final consonant in a syllable.

### Vowels in open syllables

Open syllables are syllables that do not have a final consonant.  (Open syllables may, however, have an erhua inflection.)  Mandarin vowels in open syllables have the following structure:

1. Leading glide
2. Nucleus
3. Trailing glide

Each of these three components is optional.  It is even possible to have an "empty" vowel where all three components are missing.  (According to the rules given earlier, these missing vowels are transcribed in Pinyin with a dummy `i` vowel.)

When a leading glide is present, the vowel has two forms in Pinyin transcription.  The first form has a fake initial consonant (`y` or `w`) and is used when the syllable would otherwise lack an initial consonant, as explained earlier.  The second form does not have the fake initial consonant and is used when the syllable already has an initial consonant.

The following chart shows all the possible vowels in Pinyin open syllables.  Open-syllable vowels are described as a combination of a leading glide (null, I, U, or Ü), a nucleus (null, A, O, or E), and a trailing consonant (null, I, or U).  Not all combinations are allowed.  Disallowed combinations are indicated with shaded-out cells the following table, or by entire nucleus rows being dropped when a nucleus is not allowed for the particular trailing consonant.

    +-------------------------------------------+
    |               Leading glide               |
    +-------+-----------+-----------+-----------+-------+--------
    |   -   |     I     |     U     |     Ü     | Nucl. | Trail.
    +=======+===========+===========+===========+=======+========
    |   i   |  yi |  i  |  wu |  u  |  yu |  ü  |   -   |
    +-------+-----------+-----------+-----------+-------+
    |   a   |  ya | ia  |  wa | ua  | / / / / / |   A   |
    +-------+-----------+-----------+-----------+-------+   -
    |   o   |  yo | / / |  wo | uo  | / / / / / |   O   |
    +-------+-----------+-----------+-----------+-------+
    |   e   |  ye | ie  | / / / / / | yue | üe  |   E   |
    +=======+===========+===========+===========+=======+========
    |   ai  | yai | / / | wai | uai | / / / / / |   A   |
    +-------+-----------+-----------+-----------+-------+   I
    |   ei  | / / / / / | wei | ui  | / / / / / |   E   |
    +=======+===========+===========+===========+=======+========
    |   ao  | yao | iao | / / / / / | / / / / / |   A   |
    +-------+-----------+-----------+-----------+-------+   U
    |   ou  | you | iu  | / / / / / | / / / / / |   O   |
    +=======+===========+===========+===========+=======+========

### Vowels in closed syllables

Closed syllables are syllables that have a final consonant.  (A syllable with an erhua inflection but without a final consonant counts as open, not closed.)  Mandarin vowels in closed syllables have the following structure:

1. Leading glide
2. Nucleus

The leading glide is optional but the nucleus is required.  The leading glide may be either null, I, U, or Ü.  The nucleus in closed syllables is either A or E, but the actual sound of the vowel has considerable variation depending on the context in which it occurs.  This variation also causes the Pinyin transcription of these vowels to be quite irregular.  In particular, the transcription of the Pinyin vowel in closed syllables depends on which final consonant is present in the syllable.

As noted earlier, when `r` is a final consonant, the vowel must be `e`.  However, this restriction does not apply when `r` is an erhua inflection, in which case vowel spellings for open syllables are used if there is no final consonant.

When a leading glide is present, the vowel has two forms in Pinyin transcription.  The first form has a fake initial consonant (`y` or `w`) and is used when the syllable would otherwise lack an initial consonant, as explained earlier.  The second form does not have the fake initial consonant and is used when the syllable already has an initial consonant.

The following chart shows all the possible vowels in Pinyin closed syllables.  Closed-syllable vowels are described as a combination of a leading glide (null, I, U, or Ü), a nucleus (A or E).  Additionally, the final consonant matters for how the vowel is transcribed, so it is included as a row grouping in this table (N, NG, or R), even though the final consonant is _not_ part of the vowel.  Not all combinations are allowed.  Disallowed combinations are indicated with shaded-out cells the following table, or by entire nucleus rows being dropped.

    +-------------------------------------------+
    |               Leading glide               |
    +-------+-----------+-----------+-----------+-------+--------
    |   -   |     I     |     U     |     Ü     | Nucl. | Close.
    +=======+===========+===========+===========+=======+========
    |   a   |  ya | ia  |  wa | ua  | yua | üa  |   A   |
    +-------+-----------+-----------+-----------+-------+   N
    |   e   |  yi |  i  |  we |  u  |  yu |  ü  |   E   |
    +=======+===========+===========+===========+=======+========
    |   a   |  ya | ia  |  wa | ua  | / / / / / |   A   |
    +-------+-----------+-----------+-----------+-------+   NG
    |   e   |  yi |  i  |  we |  o  |  yo | io  |   E   |
    +=======+===========+===========+===========+=======+========
    |   e   | / / / / / | / / / / / | / / / / / |   E   |   R
    +=======+===========+===========+===========+=======+========

__Note:__ The Pinyin transcriptions shown in this table do __not__ include the final consonant in the `Close.` column, which still must be transcribed separately in the syllable.

### Spelling rules

There are two systematic exceptions to the spellings given in the preceding sections.

__Rule 1:__  `ü` loses the umlaut and is written as a plain `u` when the initial consonant is alveolo-palatal (`j` `q` or `x`).

__Rule 2:__  `uo` is written as `o` when the initial consonant is labial (`b` `p` `m` or `f`).

In order to use the tonal diacritics described in the next section, it is necessary to know which vowel is the _marker vowel_ that will bear the diacritic when there is more than one vowel in the transcription.  The rules for finding the marker vowel are given here:

__Rule 3:__ If there is only one vowel letter (not counting fake initial consonants `y` and `w`), then that lone vowel letter becomes the marker vowel.

__Rule 4:__ If rule (3) does not apply, then the marker vowel is the vowel representing the nucleus.

__Rule 5:__ If rule (4) does not apply because the vowel representing the nucleus is not present in the transcription, then the marker vowel is the first vowel after the leading glide.  (There will always be a leading glide in this case.)

See the chart in the later section on "Parsing vowel sequences" for a comprehensive view of where the tone diacritics are applied in all possible multi-vowel sequences according to rules 3-5.

### Tone rules

Each syllable has one of five possible tones.  All tones except the fifth are marked by diacritics on the vowel, while the fifth tone is marked by an absence of any tonal diacritic.  When there are multiple vowels in a syllable, the _marker vowel_ is the one that takes the tonal diacritic.  See the previous section for the rules on determining the marker diacritic.

It is possible for the `ü` vowel to take a tonal diacritic, in which case the same letter will have both the umlaut diacritic and the tonal diacritic at the same time.

The following chart shows the five tones, identifying each by its standard tone number and a description, and showing the diacritic used for each:

    
     Number | Description |  Diacritic   | Example
    ========+=============+==============+=========
        1   | High        | Macron       |    ā
        2   | Rising      | Acute accent |    á
        3   | Low         | Caron        |    ǎ
        4   | Falling     | Grave accent |    à
        5   | Neutral     | (none)       |    a

Note that the diacritic for the third tone is a caron, _not_ a breve.

Tone marking in Pinyin does not generally take into account tone sandhi rules, so the actual way in which tones are pronounced does not exactly match the tones shown in Pinyin.

## CC-CEDICT Pinyin format

The CC-CEDICT Pinyin format is based on standard Pinyin, but adjusted so that it only uses US-ASCII symbols.

Each Pinyin syllable in CC-CEDICT is separated from each other by at least one space.  Since every syllable is therefore written as though it were the start of a word, apostrophes that would replace a missing initial consonant are always dropped are never used in CC-CEDICT.  Lowercase letters are used in CC-CEDICT, except that the first syllable of proper names has an uppercased first letter.

Tonal diacritics are never used in CC-CEDICT.  Instead, each Pinyin syllable has a decimal integer 1-5 suffixed directly to the end of it without any intervening space, and this decimal integer then selects the specific tone for the syllable.

Umlaut diacritics on the U are always replaced by the plain letter U followed by a colon.  Therefore, the `ü` vowel is replaced by `u:` in CC-CEDICT.  This is the only way in which colons are used in CC-CEDICT Pinyin.

Erhua inflections are written as though they were a separate syllable following the syllable they inflect.  These erhua pseudo-syllables are always notated as `r5` in CC-CEDICT Pinyin.  However, when `r` is a final consonant rather than an erhua inflection, this true `r` final is _not_ written as a separate syllable.

To notate certain interjections that feature unusual syllabic consonants (such as a syllabic `m` by itself), CC-CEDICT will have just that consonant by itself followed immediately by a tone number.

When the Chinese headword contains Latin letters or other special symbols, these symbols may make their way into the CC-CEDICT Pinyin.  In particular, Latin letters may appear by themselves in CC-CEDICT Pinyin to mean that pronunciation is based on that Latin letter.

In a few cases where the pronunciation can not be given, CC-CEDICT will mark this with crossed-out Pinyin.  To detect crossed-out Pinyin, look for at least two `x` letters in a row.  If `xx` appears anywhere in the CC-CEDICT Pinyin, the field is "crossed out."

## TOCFL Pinyin format

The TOCFL Pinyin format is close to standard Pinyin, but there are a few inconsistencies that need to be cleaned up, and a missing symbol that needs to be accounted for:

(1) The TOCFL data files use a notation involving parentheses and slashes to indicate multiple variations.  This applies not only to the Pinyin field but also to other fields.  This document assumes that these variation notations have already been taken care of elsewhere.

(2) There are two records where U+200B (ZWSP; Zero-Width Space) is inserted (invisibly) in the Pinyin.  These invisible ZWSP codepoints should be dropped.

(3) There is one record where U+0251 appears as a variant lowercase letter `a`.  This should be replaced by a regular ASCII lowercase `a`.

(4) The TOCFL data files often use breve tonal diacritics instead of the proper caron diacritics.  (But note that the caron _is_ sometimes correctly used.)  Breve diacritics should be replaced by carons.

(5) Lowercase letters are always used in TOCFL data files, except in a handful of cases involving religious terms, where the first letter is capitalized.

(6) There are three typos in the TOCFL data files where the tonal diacritic was placed on the incorrect vowel, and one typo where `n` was used instead of `ng`.  These four typos are:

        Typo    | Corrected
    ============+============
     piàolìang  | piàoliàng
     bǐfāngshūo | bǐfāngshuō
     shoúxī     | shóuxī
     gōnjǐ      | gōngjǐ

(7) The apostrophe is never used in the TOCFL data files.  Unfortunately, this is not a trivial thing to fix.  The missing apostrophe in a number of cases makes the syllable boundary unclear, resulting in various ambiguities that need to be resolved in order to convert the Pinyin to a more standard form.  The following subsections detail how to add in the missing apostrophes.

### Apostrophe alogrithm

If one knows where the syllable boundaries are within TOCFL Pinyin, it is easy to add the apostrophes in the correct places.  Specifically, any syllable that begins with a vowel (not including `w` or `y`) but is not the first syllable gets an apostrophe in front of it.  The challenge, therefore, is determining unambiguously where the syllable boundaries are within TOCFL Pinyin.

Every syllable in TOCFL Pinyin has exactly one recognized vowel sequence, so the first step in determining syllable boundaries is to find each of the recognized vowel sequences.  The only tricky part here is handling cases where two or more vowel sequences are right next to each other without any consonant separating them.  The method for determining how to split vowel sequences is described in the following subsection "Parsing vowel sequences."

Once we know where each vowel sequence is, we just have to assign each consonant to the proper vowel sequence in order to complete the parsing into syllables.  Most Pinyin consonants can only be used as initial consonants, so we will always know that those consonants go at the start of the next syllable.  We only have to worry about the ambiguous consonants that can appear in multiple positions within a syllable.  These ambiguous consonants are `n` `ng` and `r`.  Each of these ambiguous consonants is described in its own subsection to determine which syllable to assign it to.

### Parsing vowel sequences

Going through the charts given earlier of how vowels are transcribed, one can extract a list of all possible multi-vowel combinations.  Each of these combinations can then be given a tonal diacritic on the proper vowel according to spelling rules 3-5.  The following chart summarizes all possible multi-vowel combinations in both plain style and also with a tonal diacritic:

     Plain | Diacritic
    =======+===========
      ai   |    ái
      ao   |    áo
      ei   |    éi
      ia   |    iá
      iao  |    iáo
      ie   |    ié
      io   |    ió
      iu   |    iú
      ou   |    óu
      ua   |    uá
      üa   |    üá
      uai  |    uái
      ue   |    ué
      üe   |    üé
      ui   |    uí
      uo   |    uó

(In order to be comprehensive, the diacritic column should be expanded to three other columns for the other tonal tonal diacritics, replacing the acute accent with a macron, grave accent, and caron each time.)

The tonal diacritic placement is a great aid to determining where the syllables are in sequences of vowels, so do _not_ attempt to drop tonal diacritics before determining how the vowel sequences are parsed.

To parse a vowel sequence, start from the beginning and keep looking for the longest recognized match.  The longest possible vowel sequence match is length three, so start by seeing if there is a valid three-vowel sequence at the start of the string.  Then see if there is a valid two-vowel sequence at the start of the string.  If there are no valid multi-vowel sequences at the start of the string, use just the first vowel of the string (match length one).  Each time a vowel sequence is matched at the start of the string, take it out of the string and start matching again in the same way at the start of the string.  Do this until you've managed to parse the vowel vowel sequence into one or more valid vowel subsequences.  This is how vowel sequences are parsed.

### Determining R position

The consonant R is ambiguous in TOCFL Pinyin because it could be in three separate positions:  initial consonant, final consonant, or erhua inflection.  In order to determine TOCFL Pinyin syllable boundaries, you need to be able to determine which position each `r` letter is in.  Fortunately, there are rules for this that work with every Pinyin transcription in the TOCFL dataset without exception.

All the rules in this section assume that multi-vowel sequences have already been parsed into vowel subsequences according to the rules given in the preceding section.  Therefore, when we say "vowel sequence" in this section, we mean any of the parsed vowel subsequences that is either a lone vowel by itself or a recognized, valid multi-vowel combination.  It is quite possible to have multiple individual vowel sequences in a row after the parsing algorithm from the previous section has been applied.

Before stating the rules, two definitions must be made.  Let a _solitary E_ be a vowel sequence that includes only the vowel `e`.  A solitary E may have any tonal diacritic.  (Remember that this definition only applies after parsing vowel sequences, so it is possible for an `e` at the end of a sequence of several vowels in the original Pinyin string to be a solitary E if it ends up in its own vowel subsequence after parsing.)

The second definition is a _preceding consonant sequence_.  Let the preceding consonant sequence be the sequence of consonants immediately preceding a particular vowel sequence.  If a particular vowel sequence is at the very start of the word or it is preceded by another vowel sequence, the preceding consonant sequence is empty.

The third definition is a _forced initial_.  A vowel sequence has a forced initial in two cases.  The first case is that the vowel sequence is the very first vowel sequence in the word and its preceding consonant sequence is non-empty.  The second case is that the vowel sequence has a preceding consonant sequence that is not just `ng` __and__ the preceding consonant sequence either has at least two consonants or is any consonant other than `n`.  (The `ch` `zh` and `sh` digraphs are each counted as a single consonant for this rule, and `ng` can be counted either as one or two consonants.)

Given these definitions, the rules for determining R's position in the TOCFL data are as follows:

__Rule 1:__  When `r` occurs immediately before a vowel (not including `w` and `y`), `r` is an initial consonant on the syllable including that vowel.

__Rule 2:__ When `r` is (A) preceded by a solitary E; __and__ (B) that solitary E doesn't have a forced initial; __and__ (C) `r` is not followed by a vowel; __then__ `r` is a final consonant suffixed to that solitary E.

__Rule 3:__ When `r` is the last letter of a word __and__ rule 2 doesn't apply to it, then `r` is an erhua inflection.

There are no exceptions to these rules in the TOCFL dataset.

### Determining NG position

When the consonants `ng` occur together in the TOCFL dataset, they either represent a single final consonant `ng` or two separate consonants `n` and `g` where `n` is the final consonant of the preceding syllable and `g` is the initial consonant of the following syllable.  The rules for distinguishing these two cases are as follows:

__Rule 1:__  When `-ng-` occurs anywhere except between two vowels, it always represents the single final consonant `ng`.

__Rule 2:__ When `-ng-` occurs between two vowels, it represents two separate consonants `n` and `g` __except__ in the following cases, where it represents a single final consonant `ng`:

        Exception    |     Syllables
    =================+====================
     píngān          | píng ān
     zhàngài         | zhàng ài
     zǒngéryánzhī    | zǒng ér yán zhī
     dǎngàn          | dǎng àn
     fāngàn          | fāng àn
     jìngài          | jìng ài
     xiāngqīnxiāngài | xiāng qīn xiāng ài
     yīngér          | yīng ér
     chǒngài         | chǒng ài
     cóngér          | cóng ér
     dìngé           | dìng é
     fángài          | fáng ài
     gōngān          | gōng ān
     míngé           | míng é
     téngài          | téng ài
     zǒngé           | zǒng é

(In the cases of _zǒngéryánzhī_, _yīngér_, and _cóngér_, it is possible to deduce that `ng` must be a final consonant because the `r` at the end of the word is a final R, which does not allow for an initial consonant in that syllable.  The other cases are true exceptions that can't be deduced.)

### Determining N position

When the consonant `n` occurs in the TOCFL dataset, it might either be a final consonant of the preceding syllable, or an initial consonant of the following syllable, or part of an `ng` digraph.  The rules for distinguishing these three cases are as follows:

__Rule 1:__ When `n` is immediately followed by `g`, use the rules given in the previous section about NG position to determine whether `n` is a final consonant or whether it is part of an `ng` digraph.

__Rule 2:__ When `n` is the first letter in the word or it occurs immediately after another consonant, it is the initial consonant of the next syllable.

__Rule 3:__ When `n` is the last letter in the word or it occurs before any consonant except `g`, it is the final consonant of the previous syllable.

__Rule 4:__ When `n` occurs between two vowels, it is the initial consonant of the next syllable __except__ in the following cases, where it is the final consonant of the preceding syllable:

     Exception  |   Syllables
    ============+================
     fǎnér      | fǎn ér
     liànài     | liàn ài
     gǎnēn      | gǎn ēn
     jīné       | jīn é
     qīnài      | qīn ài
     ránér      | rán ér
     yībānéryán | yī bān ér yán
     yīnér      | yīn ér
     ànàn       | àn àn
     bànàn      | bàn àn
     biǎné      | biǎn é
     ēnài       | ēn ài
     jìnér      | jìn ér
     rénài      | rén ài
     shēnào     | shēn ào
     xīnài      | xīn ài

(In the cases of _fǎnér_, _ránér_, _yībānéryán_, _yīnér_, and _jìnér_, it is possible to deduce that `n` must be a final consonant because the `r` at the end of the following syllable is a final R, which does not allow for an initial consonant in that syllable.  The other cases are true exceptions that can't be deduced.)
