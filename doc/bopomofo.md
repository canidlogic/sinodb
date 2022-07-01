# Bopomofo

Sino phonetic queries use Bopomofo.  This document specifies the standard Bopomofo format, how the standard Pinyin format in `pinyin.md` is translated into Bopomofo, and special query formats for Bopomofo used in Sino.

Bopomofo transcribes individual syllables.  Each syllable has the following structure:

1. Initial
2. Medial
3. Final
4. Erhua

Each of these four elements is optional.  The only restriction is that at least one of these components must be present.  There is also a method of marking the tone, though the position of the tone mark varies (see later section).

## Initials

Bopomofo initials have a one-to-one correspondence with Pinyin consonants, with one exception.  The only exception is that the Pinyin `ng` consonant is not available as a Bopomofo initial, because it is never allowed in initial position.  The following table shows the Bopomofo initials and their corresponding Pinyin consonants:

    Plosives:   ㄆ p ㄅ b ㄊ t  ㄉ d  ㄎ k ㄍ g
    Nasals:     ㄇ m ㄋ n
    Affricates: ㄘ c ㄗ z ㄔ ch ㄓ zh ㄑ q ㄐ j
    Fricatives: ㄈ f ㄙ s ㄕ sh ㄒ x  ㄏ h
    Liquids:    ㄌ l ㄖ r

There are no equivalents for Pinyin `w` and `y` because those do not actually represent consonants in Pinyin, but rather are merely an orthography convention for when there is no initial consonant.  See `pinyin.md` for further information.

## Medials

There are three Bopomofo medials, which correspond to the three "leading glides" in `pinyin.md`:

    ㄧ  i
    ㄨ  u
    ㄩ  ü

In general, to choose the correct Bopomofo medial given a Pinyin syllable, use the tables given in `pinyin.md` to find the vowel sequence and then check what "leading glide" that vowel sequence belongs to.  (If there is no leading glide, then there will be no Bopomofo medial.)  There are, however, three exceptional cases.

The first exceptional case is that the vowel sequence consisting just of `i` in an open syllable is ambiguous in the Pinyin tables, because it could either have a leading glide `i` or no leading glide at all.  The rule is that `i` by itself in an open syllable should be interpreted as a leading glide _except_ when it is preceded by one of the following initial consonants:

    ㄘ c ㄗ z ㄔ ch ㄓ zh
    ㄙ s ㄕ sh
    ㄖ r

For these seven initial consonants, when they are followed by an `i` in an open syllable in Pinyin they are representing a syllablic consonant and the `i` is a dummy vowel.  In Bopomofo, these syllabic consonants are just written by themselves without any dummy medial.

The second exceptional case is that when `u` occurs after `j` `q` or `x` in Pinyin, it should be changed to `ü` before looking it up in the Pinyin tables.  (See spelling rule I in `pinyin.md`.)

The third exceptional case is that the medial ㄨ is dropped when the final is ㄛ and the initial is a labial ㄅ ㄆ ㄇ ㄈ.  However, Pinyin has an equivalent rule (see spelling rule 2 in `pinyin.md`), so this exceptional case should not be needed when transforming Pinyin into Bopomofo.

## Finals

There are twelve finals, which have an almost one-to-one correspondence with all combinations of nucleus and trailing glide for open syllables and nucleus and final consonant for closed syllables:

    ㄚ A
    ㄛ O
    ㄜ/ㄝ E
    ㄞ AI
    ㄟ EI
    ㄠ AU
    ㄡ OU
    ㄢ AN
    ㄣ EN
    ㄤ ANG
    ㄥ ENG
    ㄦ ER

In general, to determine the final for a Pinyin syllable, find the vowel sequence in the proper table in `pinyin.md` and then use the `Nucl.` and `Trail.` combination if you are in the open syllable table, or the `Nucl.` and `Close.` combination if you are in the closed syllable table.  Take this combination and find it in the above list to determine the appropriate Bopomofo final.  If you are in the first row in the open-syllable table where neither a nucleus nor a trailing glide is present, then there will be no final present in the Bopomofo transcription.

There are a few exceptions to this general rule.

The first exception concerns the ㄜ/ㄝ entry for "E" in the above list.  Use ㄜ when there is no medial, and ㄝ when there is a medial.  (Technically, there is a case where ㄝ can be used by itself to represent a special "ê" sound used in some interjections, but this distinction is not made by Sino.)

The second exception is that when `u` occurs after `j` `q` or `x` in Pinyin, it should be changed to `ü` before looking it up in the Pinyin tables.  (See spelling rule I in `pinyin.md`.)

The third exception is that ㄦ is ambiguous in Bopomofo, being used both as a final and as an erhua.  The rule for distinguishing these two cases is that ㄦ is a final when there is no initial nor medial, and ㄦ is an erhua when either an initial or a medial or some other final (or each of these) are present.  In other words, ㄦ is a final only when it stands alone.

## Erhua

The erhua, when present, is represented with ㄦ in Bopomofo.  This Bopomofo symbol is also used to indicate a final.  See the third exception in the previous section for the rule for distinguishing between these two cases.

## Tonal marks

Bopomofo represents syllable tone with special marker characters.  The first tone (high) is usually unmarked, while all other tones receive markers.  (Compare to Pinyin, where the fifth tone (neutral) is usually unmarked, while all other tones receive diacritics.)  Bopomofo tonal marks stand on their own, as opposed to the diacritics that are written above letters in Pinyin.  The following table shows the Bopomofo tonal marks:

     Number | Description | Modifier Letter | Unicode
    ========+=============+=================+=========
        1   | High        | Macron (*)      |    ˉ
        2   | Rising      | Acute accent    |    ˊ
        3   | Low         | Caron           |    ˇ
        4   | Falling     | Grave accent    |    ˋ
        5   | Neutral     | Dot Above       |    ˙
    
    (*) - Not usually indicated

Except for tone 5, each of these tonal marks are positioned after the final but before the erhua.  Note, then, that ㄦ is followed by a tone mark when it is a final, or preceded by a tone mark when it is an initial.

For tone 5, the tone mark comes first, before the initial.

## Formal syntax

Standard Bopomofo has the following syntax:

    transcript := ws* syllable ( ws+ syllable )* ws*
    syllable   := tone5? initial? medial? final? tone14? erhua?
    
    ws         := <any whitespace character>
    tone5      := < ˙ >
    initial    := < ㄆㄅㄊㄉㄎㄍㄇㄋㄘㄗㄔㄓㄑㄐㄈㄙㄕㄒㄏㄌㄖ >
    medial     := < ㄧㄨㄩ >
    final      := < ㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦ >
    tone14     := < ˉˊˇˋ >
    erhua      := < ㄦ >

Not all transcriptions that match this syntax are valid.  The following limitations also apply:

- At least one of `initial` `medial` and `final` must be present in each `syllable`.

- `tone5` and `tone14` may not both be present.

- If `final` is ㄦ then neither `initial` nor `medial` nor `erhua` may be present.

- If `final` is ㄜ then `medial` may not be present.

- If `medial` is ㄧ and `final` is not present, then `initial` may not be ㄘㄗㄔㄓㄙㄕㄖ.

- If `initial` is ㄅㄆㄇㄈ and `final` is ㄛ, then `medial` may not be ㄨ.

Each unique Bopomofo syllable is different from all others, with one exception.  Suppose that a syllable A has `initial` `medial` `final` and `erhua` equivalent to a syllable B.  Suppose that syllable A has neither `tone5` nor `tone14`.  Suppose that syllable B has `tone14` set to ˉ (tone 1).  Then, A and B are equivalent.  (In other words, if a syllable has no tonal marks, then it is equivalent to the same syllable with tone mark 1.)

## Query format

A special Bopomofo _query format_ is allowed for performing phonetic queries in Sino.  This query format is a superset of the standard Bopomofo format, so that standard Bopomofo works as expected, with one minor difference.  The minor difference is that an absence of any tonal mark within a syllable is interpreted in query format as meaning the syllable should match syllables of any tone, while in standard Bopomofo the absence of any tonal mark means tone 1.  In other words, the only difference between standard Bopomofo and its query format subset is that tonal marks should always be explicit if you want to match by tone in query format.

In standard Bopomofo, a transcription is a sequence of syllables.  In query format, a query is a sequence of _entities,_ where each entity may either be a _query key_ or a _wildcard sequence._  Wildcard sequences are a sequence of one or more `*` and/or `?` characters.  `*` means any sequence of zero or more syllables, while `?` means any single syllable.  These can be combined, such that for example `???*` means any sequence of three or more syllables.  Erhua inflections are _not_ counted as separate syllables.  Wildcard sequences that appear next to each other in the query are collapsed into a single wildcard sequence, and then each wildcard sequence is normalized into a sequence of zero or more `?` wildcards followed optionally by a `*` wildcard.

Query keys use standard Bopomofo syllable syntax, with the following extensions:

- If no tone mark is indicated, the query can match syllables of any tone.  If you want to match tone 1 only, explicitly include a tone 1 mark, even though this are usually not included in standard Bopomofo.

- Tone marks may appear at any position within the query key, but there may be at most one tone mark per query key.

- You may use `(ㄦ)` in place of an erhua inflection to indicate that the query key can match syllables both with and without an erhua inflection.

- If you prefix the query key with the ASCII tilde `~` then an approximate match is performed for initial, medial, and finals.  If no initial is present in the query key, then any initial or no initial at all may match; if no medial is present in the query key, then any medial or no medial at all may match; if no final is present in the query key, then any final or no final at all may match.  Without the tilde, if no initial is present in the query key, then there must be no initial to match, and so forth.  The tilde does not affect tonal matching and erhua matching, which can be controlled with the syntax conventions noted above.

Syntax of query format is as follows:

    query   := ws* entity ( ws+ entity )* ws*
    entity  := ( key | wildseq )

    wildseq := ( "*" | "?" )+
    key     := ( "~" )? initial? medial? final? erhua?

    initial := tone-c? initial-c tone-c?
    medial  := tone-c? medial-c tone-c?
    final   := tone-c? final-c tone-c?
    erhua   := tone-c? ( ㄦ | "(" ㄦ ")" ) tone-c?

    ws        := <any whitespace character>
    initial-c := < ㄆㄅㄊㄉㄎㄍㄇㄋㄘㄗㄔㄓㄑㄐㄈㄙㄕㄒㄏㄌㄖ >
    medial-c  := < ㄧㄨㄩ >
    final-c   := < ㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦ >
    tone-c    := < ˉˊˇˋ˙ >

Not all queries that match this syntax are valid.  The following limitations also apply:

- Unless a `key` has a tilde prefix, at least one of `initial` `medial` and `final` must be present in each `key`.

- At most one `tone-c` may be present in each `key`.

- If `final` is ㄦ then neither `initial` nor `medial` nor `erhua` may be present.

- If `final` is ㄜ then `medial` may not be present.

- Unless a `key` has a tilde prefix, if `medial` is ㄧ and `final` is not present, then `initial` may not be ㄘㄗㄔㄓㄙㄕㄖ.

- If `initial` is ㄅㄆㄇㄈ and `final` is ㄛ, then `medial` may not be ㄨ.

## Storage format

A special Bopomofo _storage format_ is used for storing Bopomofo transcriptions within Sino.  This special format is designed so that Bopomofo in storage format can be queried with the SQL `LIKE` operator for efficient matching.

Storage format is the same as standard Bopomofo format, with the following differences:

- Each syllable begins with an ASCII `+` sign and no whitespace is used between, before, or after syllables.

- Tone 1 is always explicitly notated and never left implicit.

- Tone 5 marks are placed in the same position as tone 1-4 marks.

- When `initial` `medial` `final` or `erhua` is not present, each of these is replaced by an ASCII `.` period instead of just being omitted.

Because of these rules, each Bopomofo syllable in storage format always has exactly six codepoints:

1. `+`
2. Initial or `.`
3. Medial or `.`
4. Final or `.`
5. Tone mark
6. Erhua or `.`

The fixed width, predictable positioning of fields, and the use of a `+` marker in front of each syllable allows each of the wildcard and optional feature queries from query format to be implemented efficiently in SQL queries.
