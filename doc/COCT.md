# Import notes for COCT dataset

These import notes apply to the reformatted mirror of the COCT dataset in CSV format, given at the mirror site https://canidlogic.github.io/sinodata/

The original COCT dataset was obtained from https://coct.naer.edu.tw/download/tech_report/ but note that the Sino database assumes the December 2, 2020 version specifically, which is the version used on the mirror site.

Given the reformatted CSV file, the first column will contain the level number.  According to the supplementary notes distributed along with the TOCFL dataset, COCT level 1 corresponds to TOCFL level Novice 2, the levels track each other until COCT level 6 corresponds to TOCFL 5, and then COCT level 7 is one beyond the last TOCFL level.  Therefore, each of the COCT levels should be increased by one when integrating with TOCFL data.

Within the word data field, variant parentheses `U+FF08` and `U+FF09` must be changed to regular ASCII parentheses `(` and `)` respectively, and variant slash `U+FF0F` must be changed to regular ASCII forward slash `/`

Each word data field might expand to multiple words.  First of all, if there are forward slashes, divide into separate components using the forward slash.  Second of all, if there are characters in parentheses within any component, expand that component into two alternatives, one without the characters in parentheses and the other with.

Words might have a sequence of decimal digits after them, which are an index into a phonetic readings array that the Sino database does not make use of.  These digits should be dropped when they occur.
