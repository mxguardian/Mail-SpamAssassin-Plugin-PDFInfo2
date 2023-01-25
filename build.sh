#!/usr/bin/sh
#
# This script concatenates all the source files into a single plugin file in the dist directory
#

OUTFILE=dist/PDFInfo2.pm

cp /dev/null $OUTFILE

sed -e '/^=cut/q' lib/Mail/SpamAssassin/Plugin/PDFInfo2.pm >>$OUTFILE
echo >>$OUTFILE
sed '/^use Mail::SpamAssassin::PDF::/d' lib/Mail/SpamAssassin/PDF/Core.pm >>$OUTFILE
echo >>$OUTFILE
sed '/^use Mail::SpamAssassin::PDF::/d' lib/Mail/SpamAssassin/PDF/Context.pm >>$OUTFILE
echo >>$OUTFILE
sed '/^use Mail::SpamAssassin::PDF::/d' lib/Mail/SpamAssassin/PDF/Context/Info.pm >>$OUTFILE
echo >>$OUTFILE
sed '/^use Mail::SpamAssassin::PDF::/d' lib/Mail/SpamAssassin/PDF/Filter/Decrypt.pm >>$OUTFILE
echo >>$OUTFILE
sed '/^use Mail::SpamAssassin::PDF::/d' lib/Mail/SpamAssassin/PDF/Filter/FlateDecode.pm >>$OUTFILE
echo >>$OUTFILE
sed '/^use Mail::SpamAssassin::PDF::/d' lib/Mail/SpamAssassin/PDF/Parser.pm >>$OUTFILE
echo >>$OUTFILE
sed -e '1,/^=cut/d' lib/Mail/SpamAssassin/Plugin/PDFInfo2.pm >>$OUTFILE


