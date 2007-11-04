#!/usr/bin/perl

use Module::Build;

my $build = Module::Build->new(
	dist_name => 'File-DesktopEntry',
	dist_version_from => 'lib/File/DesktopEntry.pm',
	dist_author => 'Jaap Karssenberg <pardus@cpan.org>',
	license => 'perl',
	requires => {
		'Carp'		=> 0,
		'File::Spec'	=> 0,
		'File::Path'	=> 0,
		'File::BaseDir'	=> '0.03',
		($^O eq 'MSWin32' ? (
			'Win32::Process'   => 0,
		) : ()),

	},
	build_requires => {
		'Module::Build'  => '0.24',
		'Test::More'     => 0,
	},
	create_makefile_pl => 'passthrough',
	#dynamic_config => 1,
);

$build->create_build_script;

