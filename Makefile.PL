
use ExtUtils::MakeMaker;

WriteMakefile(
	'NAME'		=> 'File::DesktopEntry',
	'VERSION_FROM'	=> 'DesktopEntry.pm',
	'PREREQ_PM'	=> {
		'File::Spec'	=> 0,
	},
	($] >= 5.005
    		? (AUTHOR => 'Jaap Karssenberg <pardus@cpan.org>')
		: ()
	),
);
