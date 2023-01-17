use strict;
use warnings;
use Test::More;
use PDF::CMap;
use Data::Dumper;

my $stream = <<EOF;
/CIDInit /ProcSet findresource begin
12 dict begin
begincmap
/CIDSystemInfo
<< /Registry (Adobe)
/Ordering (UCS) /Supplement 0 >> def
/CMapName /Adobe-Identity-UCS def
/CMapType 2 def
1 begincodespacerange
<0000> <FFFF>
endcodespacerange
67 beginbfchar
<20> <0020>
<21> <0021>
<24> <0024>
<2C> <002C>
<2D> <002D>
<2E> <002E>
<2F> <002F>
<30> <0030>
<31> <0031>
<32> <0032>
<33> <0033>
<34> <0034>
<35> <0035>
<36> <0036>
<37> <0037>
<38> <0038>
<39> <0039>
<3A> <003A>
<3F> <003F>
<40> <0040>
<41> <0041>
<42> <0042>
<43> <0063>
<44> <0064>
<45> <0065>
<46> <0066>
<47> <0067>
<48> <0068>
<49> <0069>
<4C> <006C>
<4D> <006D>
<4E> <006E>
<4F> <006F>
<50> <0050>
<51> <0051>
<52> <0072>
<53> <0073>
<54> <0074>
<55> <0075>
<56> <0076>
<57> <0077>
<59> <0079>
<5A> <005A>
<5F> <005F>
<61> <0061>
<62> <0062>
<63> <0063>
<64> <0064>
<65> <0065>
<66> <0066>
<67> <0067>
<68> <0068>
<69> <0069>
<6B> <006B>
<6C> <006C>
<6D> <006D>
<6E> <006E>
<6F> <006F>
<70> <0070>
<72> <0072>
<73> <0073>
<74> <0074>
<75> <0075>
<77> <0077>
<78> <0078>
<79> <0079>
<92> <2019>
endbfchar
endcmap CMapName currentdict /CMap defineresource pop end end
EOF

my $cmap = PDF::CMap->new();
$cmap->parse_stream($stream);

print Dumper($cmap->{cmap});

