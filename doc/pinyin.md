# Pinyin notes

This document describes standard Pinyin, the specific formats used in the TOCFL dataset and CC-CEDICT, and the process of converting from TOCFL format to CC-CEDICT.

## Pinyin transcription

Mandarin consonants are transcribed into Pinyin as follows.  (Where pairs of consonants are given, the first in the pair is aspirated and the second is unaspirated.)

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

Mandarin vowels in open syllables (that is, syllables without any final consonant) consist of a leading glide, a nucleus, and a trailing glide.  Each of these components is optional, and it is indeed possible to have an "empty" vowel that is composed of nothing at all.  When there is a leading glide, there are two spellings of the vowel, one used when there is no initial consonant in the syllable and the other used when there is an initial consonant.  The columns in the following table show the leading glide vowel (or `-` for no leading glide), while the rows show the trailing glide and the nucleus.  When there are two entries in a cell, the first is the spelling without an initial consonant and the second is the spelling after an initial consonant.

    +-------------------------------------------+
    |               Leading glide               |
    +-------+-----------+-----------+-----------+
    |   -   |     I     |     U     |     Ü     | Nucl.   Trail.
    +=======+===========+===========+===========+=======+========
    |   i   |  yi |  i  |  wu |  u  |  yu |  ü  |   -   |
    +-------+-----------+-----------+-----------+-------+
    |   a   |  ya | ia  |  wa | ua  | / / / / / |   A   |
    +-------+-----------+-----------+-----------+-------+   -
    |   o   | / / / / / |  wo | uo  | / / / / / |   O   |
    +-------+-----------+-----------+-----------+-------+
    |   e   |  ye | ie  | / / / / / | yue | üe  |   E   |
    +=======+===========+===========+===========+=======+========
    |   ai  | / / / / / | wai | uai | / / / / / |   A   |
    +-------+-----------+-----------+-----------+-------+   I
    |   ei  | / / / / / | wei | ui  | / / / / / |   E   |
    +=======+===========+===========+===========+=======+========
    |   ao  | yao | iao | / / / / / | / / / / / |   A   |
    +-------+-----------+-----------+-----------+-------+   U
    |   ou  | you | iu  | / / / / / | / / / / / |   O   |
    +=======+===========+===========+===========+=======+========

When vowels are used in closed syllables (that is, syllables with a final consonant), then there are only two nucleus vowels and no trailing glide.  However, surface forms show more variation due to the interactions between sounds.  The following chart has the same structure as the previous, except instead of a trailing glide column it has a closing consonant column:

    +-------------------------------------------+
    |               Leading glide               |
    +-------+-----------+-----------+-----------+
    |   -   |     I     |     U     |     Ü     | Nucl.   Close.
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

@@TODO:

## CC-CEDICT format

The CC-CEDICT format that we want to convert into only uses ASCII letters, ASCII colon, ASCII decimal digits 1-5, and ASCII space.  Pinyin syllables are separated from each other by spaces.  The colon is only used immediately after `u` or `U` to indicate that the U letter should have an umlaut.  The decimal digits 1-5 are only used at the end of each syllable to indicate the tone.  Letters are always lowercase, except that some Pinyin syllables may have an uppercase first letter to indicate a proper name.

Each Pinyin syllable in the CC-CEDICT format follows either the regular format or one of the exceptional formats.  In the regular format, the syllable is spelled according to standard Pinyin orthography without any tonal diacritics.  U-umlaut is always represented as `u:` or `U:` and a single decimal digit 1-5 is always suffixed directly to the syllable (without any whitespace) to indicate its tone.  The first character is always a letter and the last character is always the decimal digit.  The first letter may be uppercase to indicate a proper name, but otherwise letters are always lowercase.

The decimal suffixes indicate tone as follows.  The table shows the tone numbers, the tone description, and the corresponding diacritic that would be used in standard Pinyin.

     Digit |      Tone      | Diacritic
    =======+================+===========
       1   | High-level     |     ā
       2   | Rising         |     á
       3   | Falling-rising |     ǎ
       4   | Falling        |     à
       5   | Neutral        |     a
