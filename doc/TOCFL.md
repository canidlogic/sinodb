# Import notes for TOCFL dataset

These import notes apply to the reformatted mirror of the TOCFL dataset in CSV format, given at the mirror site https://canidlogic.github.io/sinodata/

The original TOCFL dataset was obtained from https://tocfl.edu.tw/index.php/exam/download but note that the Sino database assumes the April 11, 2022 version specifically, which is the version used on the mirror site.

(1) Codepoint range `[U+FF08, U+FF09]` are variant parentheses, which should be replaced by ASCII parentheses immediately.  Only occur in one entry enclosing Bopomofo.

(2) Codepoint `U+200B` is a zero-width space that is inserted between Pinyin syllables in only two records.  It should be dropped when it occurs.

(3) Codepoint `U+0251` is a variant lowercase a that only appears in one record.  It should be replaced by ASCII lowercase a.

(4) Pinyin uses breves in the data file instead of the standard carons.  They should be replaced by the equivalent carons.  However, note that e-caron is used correctly, and in at least one place u-caron is already present.

(5) Uppercase ASCII letters used in Pinyin only for 道教, 佛教, 基督教, 回教/伊斯蘭教, 基督, which are all names of religions or religious figures.  Uppercase will be converted to lowercase.

(6) In some headword and Pinyin fields, duplicate values result when there are both slashes and parentheticals at the same time; drop duplicates while decoding.

(7) In one case, there is `conj` used for word class instead of `Conj` otherwise all seems accurate; to fix, normalize case so that first character (always a letter) is uppercase, and anything remaining is lowercase.

(8) Codepoint ranges `[U+02CA, U+02D9]` and `[U+3100, U+3129]` are Bopomofo related.  Only occur within parentheses in Chinese headword, where they are used to distinguish pronunciation of an ambiguous character (which is redundant with the pinyin).  Not necessarily at the end of the Chinese headword.  The parentheses and the Bopomofo within can be dropped.

(9) `U+3001` Ideographic comma only occurs in one of the word category labels.  It never appears in Chinese headwords or any other field.

(10) ASCII parentheses (after converting the exceptional parentheses from (1)) have two uses.  First, they can enclose Bopomofo in the Chinese headword only, in which case the whole parenthetical can be dropped.  Second, they can enclose an optional syllable at the end of a word, in both the Chinese headword and the Pinyin.  When used in conjunction with the slash, the parentheses have higher precedence.  Note that the way an optional syllable is indicated in the Chinese headword and the Pinyin may not always be consistent, with for example a parenthesis group used in the headword versus a slash alternative in the Pinyin.  In this second use, the parentheses can NOT be dropped.

(11) ASCII hyphen is only used within the part-of-speech field to name certain parts of speech.

(12) ASCII forward slash may be used within Chinese headword, Pinyin, and part-of-speech fields to indicate that the field has multiple values, each separated by slash.  Note that the number of values in the headword field is NOT always the same as the number of values in the Pinyin field; for example, there might be two different character renderings but only one pronunication.

(13) There's a lot of extra whitespace `U+0020` space characters so be sure to apply a lot of whitespace trimming while parsing records.

(14) Some part-of-speech fields are blank.

(15) See `pinyin.md` for notes about the Pinyin format used within TOCFL files.

(16) In a few cases where there is exactly one Pinyin reading given but two headwords given, there is actually an abbreviated Pinyin form that should have been given but is missing.  The following table gives all of these cases:

     Pinyin form given | Missing abbreviation
    ===================+======================
     shēngyīn          | shēng
     bǎozhèng          | zhèng
     bùzhì             | bù
     fǎngwèn           | fǎng
     gǔjī              | jī
     jiànjiàn          | jiàn
     mòmò              | mò

The forms given in this table have already had their Pinyin normalized.  Remember, these additions only apply if there is exactly two headwords and exactly one Pinyin in the original record.  In all cases but one, the abbreviated Pinyin form should be added after the one already present.  The exception is bùzhì, where the abbreviated Pinyin form should be added _before_ the one already present.
