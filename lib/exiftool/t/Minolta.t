# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl t/Minolta.t'

######################### We start with some black magic to print on failure.

# Change "1..N" below to so that N matches last test number

BEGIN { $| = 1; print "1..4\n"; $Image::ExifTool::noConfig = 1; }
END {print "not ok 1\n" unless $loaded;}

# test 1: Load ExifTool
use Image::ExifTool 'ImageInfo';
use Image::ExifTool::Minolta;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

use t::TestLib;

my $testname = 'Minolta';
my $testnum = 1;

# test 2: Extract information from Minolta.jpg
{
    ++$testnum;
    my $exifTool = new Image::ExifTool;
    my $info = $exifTool->ImageInfo('t/images/Minolta.jpg');
    print 'not ' unless check($exifTool, $info, $testname, $testnum);
    print "ok $testnum\n";
}

# test 3: Write some new information
{
    ++$testnum;
    my @writeInfo = (
        ['Caption-Abstract' => 'A new caption/abstract'],
        ['MinoltaDate' => '2005:01:16'],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum);
    print "ok $testnum\n";
}

# test 4: Write rewriting MRW image
{
    ++$testnum;
    my @writeInfo = (
        ['FocusMode' => 'MF'],
        ['LastFileNumber' => '123'],
    );
    print 'not ' unless writeCheck(\@writeInfo, $testname, $testnum, 't/images/Minolta.mrw');
    print "ok $testnum\n";
}


# end
