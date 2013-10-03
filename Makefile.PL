use strict;
use warnings;

use 5.006001;

use ExtUtils::MakeMaker;

WriteMakefile
  (
   'NAME'	        => 'File::DesktopEntry',
   'ABSTRACT'           => 'Module to handle .desktop files',
   'AUTHOR'             => 'Jaap Karssenberg <pardus@cpan.org>',
   'DISTNAME'           => "File-DesktopEntry",
   'VERSION_FROM'       => 'lib/File/DesktopEntry.pm',
   'LICENSE'            => 'perl',
   'MIN_PERL_VERSION'   => '5.8.6',
   'BUILD_REQUIRES'     => {
     'Carp'           => 0,
     'File::Spec'     => 0,
     'File::Path'     => 0,
     'File::BaseDir'  => '0.03',
     ($^O eq 'MSWin32' ? ('Win32::Process' => 0) : ()),
   },
   'CONFIGURE_REQUIRES' => {
     "ExtUtils::MakeMaker" => "6.30"
   },
   'LIBS'               => [''], # e.g., '-lm'
   'dist' => {
	      COMPRESS => "gzip -9f",
	      SUFFIX => "gz",
	     },
  'test' => {
    'TESTS' => "t/*.t"
  },
  META_MERGE => {
    resources => {
      repository => 'https://github.com/mbeijen/File-DesktopEntry',
    },
  },
  );
