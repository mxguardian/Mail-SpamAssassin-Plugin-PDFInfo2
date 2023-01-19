#!/usr/bin/sh

PDFINFO=build/PDFInfo2.pm

cp /dev/null $PDFINFO

sed '/^use PDF::/d' lib/PDF/Core.pm >>$PDFINFO
echo >>$PDFINFO
sed '/^use PDF::/d' lib/PDF/Context.pm >>$PDFINFO
echo >>$PDFINFO
sed '/^use PDF::/d' lib/PDF/Context/Info.pm >>$PDFINFO
echo >>$PDFINFO
sed '/^use PDF::/d' lib/PDF/Filter/Decrypt.pm >>$PDFINFO
echo >>$PDFINFO
sed '/^use PDF::/d' lib/PDF/Filter/FlateDecode.pm >>$PDFINFO
echo >>$PDFINFO
sed '/^use PDF::/d' lib/PDF/Parser.pm >>$PDFINFO
echo >>$PDFINFO
sed '/^use PDF::/d' lib/PDFInfo2.pm >>$PDFINFO


