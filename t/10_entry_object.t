use strict;
use Test::More tests => 9;
use File::Spec;
use File::DesktopEntry;

my $tree = do File::Spec->catfile(qw/t foo.datadump/);

my $entry = File::DesktopEntry->new_from_file(
	File::Spec->catfile(qw/t foo.desktop/) );

ok( eq_array([keys %$entry], ['file']), 'no premature hashing'); # 1

$entry->hash;

is_deeply($entry->{groups}, $tree, 'raw data is correct'); # 2

ok( $entry->get_value('Comment') eq 'The best viewer for Foo objects available!',
	'get_value() works' ); # 3
ok( $entry->get_value('Comment', undef, 'eo') eq 'Tekstredaktilo',
	'get_value() works with locale string' ); # 4
ok( $entry->get_value('Comment', undef, 'ja') eq "\x{30c6}\x{30ad}\x{30b9}\x{30c8}\x{30a8}\x{30c7}\x{30a3}\x{30bf}",
	'get_value() works with locale in utf8' ); # 5

ok(! $entry->wants_uris, 'wants_uris()'); # 6
ok($entry->wants_list, 'wants_list()'); # 7

my $exec = $entry->parse_Exec(qw/bar baz/);

ok($exec eq q#fooview 'bar' 'baz'#, 'parse_Exec works'); # 8

$entry->{data}{Exec} =~ s/ \%F//;
$exec = $entry->parse_Exec(qw/bar baz/);

ok($exec eq q#fooview 'bar' 'baz'#, 'default parse_Exec works'); # 9


