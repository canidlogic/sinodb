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

(17) The Pinyin in the records can be matched with headwords according to the following algorithm.  First, define the _count_ of a Pinyin reading as the number of syllables, with erhua R counted as its own syllable (but non-erhua final R in an `er` syllable is _not_ separate); also, define the _count_ of a headword as the number of Han characters within the headword.  Second, expand variation notation involving slashes and parentheses out into separate values, such that no parentheses or slashes remain in any of the Pinyin or Han readings.

Third, handle the _first exceptional case._  If there are exactly the same number of Pinyin and Han readings, and each Pinyin reading has the same count as the corresponding Han reading when matched in the order given, then the Pinyin and Han readings should be matched to one another in the order they appear in both arrays.

Fourth, handle the _second exceptional case._  The second exceptional case uses a lookup table for three records which would otherwise have ambiguous mappings.  In the following table, the three exceptional records are given, with each having three headwords, and the matching Pinyin for each headword is shown:

     Exception | Headword | Pinyin
    ===========+==========+========
               |   這裡   | zhèlǐ
         1     |   這裏   | zhèlǐ
               |   這兒   | zhèr
    -----------+----------+--------
               |   那裡   | nàlǐ
         2     |   那裏   | nàlǐ
               |   那兒   | nàr
    -----------+----------+--------
               |   哪裡   | nǎlǐ
         3     |   哪裏   | nǎlǐ
               |   哪兒   | nǎr

To detect one of these exceptional cases, check for a record that has three headwords that exactly match one of the three exceptions given in the above table.  The two Pinyin in the table should match the Pinyin already given for the record.  (Since the count of all headwords and Pinyin in the table is two, the matching would be ambiguous without this exceptional case for these three records.)

Fifth is the general case, which is used when neither of the two exceptional cases apply.  Match headwords and Pinyin by connecting headwords to Pinyin whenever their counts are the same.  If there is only one headword with a certain count, then multiple Pinyin can have that count, and all of them will be mapped to that headword.  However, if more than one headword has a certain count, then only one Pinyin can have that count, and that Pinyin will be assigned to each of the headwords with that count.  If there exists any count value for which there are multiple headwords _and_ multiple Pinyin in the same record, then matching is ambiguous and the matching algorithm fails.  At the end of the general matching process, each headword and each Pinyin should have been used in at least one match, or the matching algorithm fails.

In the TOCFL dataset version assumed for Sino, this matching algorithm should succeed for all records.
