# Bopomofo

Sino phonetic queries use Bopomofo.  This document specifies the Bopomofo format, and how the standard Pinyin format in `pinyin.md` is translated into Bopomofo.

Bopomofo transcribes individual syllables.  Each syllable has the following structure:

1. Initial
2. Medial
3. Final
4. Erhua

Each of these four elements is optional.  The only restriction is that at least one of these components must be present.

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

     Number | Description | Modifier Letter | Example
    ========+=============+=================+=========
        1   | High        | Macron (*)      |    ˉ
        2   | Rising      | Acute accent    |    ˊ
        3   | Low         | Caron           |    ˇ
        4   | Falling     | Grave accent    |    ˋ
        5   | Neutral     | Dot Above       |    ˙
    
    (*) - Not usually indicated

Except for tone 5, each of these tonal marks are positioned after the final but before the erhua.  Note, then, that ㄦ is followed by a tone mark when it is a final, or preceded by a tone mark when it is an initial.

For tone 5, the tone mark comes first, before the initial.
