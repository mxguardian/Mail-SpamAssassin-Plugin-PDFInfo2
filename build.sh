#!/usr/bin/sh

PDFINFO=build/PDFInfo2.pm

cp /dev/null $PDFINFO

sed '/^use Mail::SpamAssassin::PDF::/d' lib/Mail/SpamAssassin/PDF/Core.pm >>$PDFINFO
echo >>$PDFINFO
sed '/^use Mail::SpamAssassin::PDF::/d' lib/Mail/SpamAssassin/PDF/Context.pm >>$PDFINFO
echo >>$PDFINFO
sed '/^use Mail::SpamAssassin::PDF::/d' lib/Mail/SpamAssassin/PDF/Context/Info.pm >>$PDFINFO
echo >>$PDFINFO
sed '/^use Mail::SpamAssassin::PDF::/d' lib/Mail/SpamAssassin/PDF/Filter/Decrypt.pm >>$PDFINFO
echo >>$PDFINFO
sed '/^use Mail::SpamAssassin::PDF::/d' lib/Mail/SpamAssassin/PDF/Filter/FlateDecode.pm >>$PDFINFO
echo >>$PDFINFO
sed '/^use Mail::SpamAssassin::PDF::/d' lib/Mail/SpamAssassin/PDF/Parser.pm >>$PDFINFO
echo >>$PDFINFO
sed '/^use Mail::SpamAssassin::PDF::/d' lib/Mail/SpamAssassin/Plugin/PDFInfo2.pm >>$PDFINFO


