package File::DesktopEntry;

use strict;
use File::Spec;

our $VERSION = 0.02;

=head1 NAME

File::DesktopEntry - Object to handle .desktop files

=head1 SYNOPSIS

	use File::DesktopEntry;
	
	my $entry = File::DesktopEntry->new_from_file(
		'/usr/share/applications/mozilla-firefox.desktop' );
	
	# ...
	
	die $entry->get_value('Name')." isn't an application\n"
		unless $entry->get_value('Type') eq 'Application';
	print "Using ".$entry->get_value('Name')." to open http://perl.org\n";
	unless (fork) { # child
		$entry->exec('http://perl.org');
	}

=head1 DESCRIPTION

This module is used to work with .desktop files. The format of these files
is specified by the freedesktop "Desktp Entry" specification.
See L<http://freedesktop.org/wiki/Standards_2fdesktop_2dentry_2dspec>.
For this module version 0.9.4 of the specification was used.

This module was written to support L<File::MimeInfo::Applications>.

Please remember: case is significant, most key names contain capitals.

=head1 EXPORT

None by default.

=head1 METHODS

=over 4

=item C<new_from_file(PATH)>

Constructor for a desktop entry specified by file PATH.

=cut

sub new_from_file {
	my ($class, $file) = @_;
	bless {file => $file}, $class;
}

=item C<new_from_data(TEXT)>

Constructor for a desktop entry specified by the content of
string TEXT.

=cut

sub new_from_data {
	my ($class, $text) = @_;
	bless {text => $text}, $class;
}

=item C<hash( )>

Parse data from file or text. This method must be called after
the constructor if you intend to use the hash with raw data.

If you access the data with a method this routine will be called
automaticly.

This step is provided so that you can pass around desktop entry
objects without actually reading their content easily.

=cut

sub hash {
	my $self = shift;
	$self->readfile unless exists $self->{text};
	my $text = delete $self->{text};

	my $group;
	for (split /[\r\n]/, $text) {
		chomp;
		next if /^\s*#/ or not /\S/;

		if (/^\[(.+)\]$/) { # group
			$group = $1;
		}
		elsif (! defined $group) {
			die "Parse error: content in desktop entry without group header";
		}
		elsif (/^(.+?)=(.*)$/) { # key=value
			$self->{groups}{$group}{$1} = $2;
		}
		else {
			die "Parse error: strange content in desktop entry";
		}
		# TODO better error messages
	}
	$self->{data} = $self->{groups}{"Desktop Entry"};
	$self->{_hashed}++;
	
	$self->checks;
	
	return $self;
}

sub readfile {
	my $self = shift;
	open FILE, "<$self->{file}" or die "Could not open $self->{file}\n";
	binmode FILE, ':utf8' unless $] < 5.008;
	$self->{text} = join '', <FILE>;
	close FILE;
}

sub checks {
	my $self = shift;
	for (qw/Type Encoding Name/) {
		warn "Warning: Required field $_ missing in desktop entry\n"
			unless exists $self->{data}{$_};
	}
	warn "Warning: Encoding $self->{data}{Encoding} not supported for desktop entry - trying utf8\n"
		if  exists $self->{data}{Encoding}
		and $self->{data}{Encoding} ne 'UTF-8';
}

=item C<get_value(NAME, GROUP, LOCALE)>

Returns the content of a field in the desktop entry.
Content is not parsed, so boolean false returns as the string 'false'.

GROUP and LOCALE are optional.

=cut

sub get_value {
	my ($self, $name, $group, $locale) = @_;
	die "usage: get_value(NAME, [GROUP], [LOCALE])" unless length $name;

	$self->hash unless $self->{_hashed};
	
	$group = 'Desktop Entry' unless defined $group and length $group;
	$name .= "[$locale]" if defined $locale and length $locale;
	return exists($self->{groups}{$group}{$name})
		? $self->{groups}{$group}{$name} : undef ;
}

=item C<system(ARGV)>

Run the application specified by this desktop entry with arguments ARGV.
This method uses the C<system()> system call and will only return after
the application has ended.

This method of course fails if the current desktop entry doesn't specify
an application at all.

If the desktop entry specifies that the program needs to be executed in a
terminal the $TERMINAL environment variable is used. If this variable is not
set L<xterm(1)> is used.

=item C<exec(ARGV)>

Like C<system(ARGV)> but uses the C<exec()> system call. This method
is expected not to return but to replace the current process with the 
application you try to run.

This is usefull in combination with C<fork()> to run background processes.

=cut

sub system { unshift @_, 'system'; goto \&_run }
sub exec   { unshift @_, 'exec';   goto \&_run }

sub _run {
	my $call = shift;
	my $self = shift;
	
	die "desktop entry is not an Application"
		unless $self->{data}{Type} eq 'Application';

	my @exec = $self->parse_Exec(@_);

	if ($self->{data}{Terminal} eq 'true') {
		my $term = $ENV{TERMINAL} || 'xterm -e';
		@exec = (split(/\s+/, $term), @exec);
	}
	
	if ($call eq 'exec') { CORE::exec(@exec)   }
	else                 { CORE::system(@exec) }
}

=item C<wants_uris( )>

Returns true if the Exec string for this desktop entry specifies that the
application uses URIs instead of paths. This can be used to determine
whether an application uses a VFS library.

=cut

sub wants_uris {
	my $self = shift;
	$self->hash unless $self->{_hashed};
	die "No Exec string defined for desktop entry"
		unless exists $self->{data}{Exec};
	my $exec = $self->{data}{Exec};
	$exec =~ s/\%\%//g;
	return $exec =~ /\%u/i;
}

=item C<wants_list( )>

Returns true if the Exec tring for this desktop entry specifies that the
application can handle multiple arguments at once.

=cut

sub wants_list {
	my $self = shift;
	$self->hash unless $self->{_hashed};
	die "No Exec string defined for desktop entry"
		unless exists $self->{data}{Exec};
	my $exec = $self->{data}{Exec};
	$exec =~ s/\%\%//g;
	return ($exec !~ /\%/) || ($exec =~ /\%[FUDN]/);
}
	
=item C<parse_Exec(ARGV)>

Returns a string to execute based on the Exec format in this desktop entry.

If necessary this method tries to convert between paths and URLs but this
is not perfect.

=cut

sub parse_Exec {
	my $self = shift;
	my @argv = @_;
	
	die 'Application takes one argument'
		if @argv != 1 and ! $self->wants_list;
	
	my $exec = $self->{data}{Exec};
	my $_exec = $exec;
	$_exec =~ s/\%\%//g;
	$exec .= ' %F' if $_exec !~ /\%/; # default to files
	
	$exec =~ s{(\%.)}{
		if ($1 eq '%%') { '%' }
		elsif (lc($1) eq '%f') { # file
			join ' ', map "'$_'", _paths(@argv);
		}
		elsif (lc($1) eq '%u') { # uri
			join ' ', map "'$_'", _uris(@argv);
		}
		elsif (lc($1) eq '%d') { # directory
			for (_paths(@argv)) {
				next if -d $_;
				my ($vol, $dirs, undef) = File::Spec->splitpath($_);
				$_ = File::Spec->catpath($vol, $dirs);
			}
			join ' ', map "'$_'", @argv;
		}
		elsif (lc($1) eq '%n') { # name
			for (_paths(@argv)) {
				my (undef, undef, $file) = File::Spec->splitpath($_);
				$_ = $file;
			}
			join ' ', map "'$_'", @argv;
		}
		elsif ($1 eq '%i') { # icon
			(exists $self->{data}{Icon} and length $self->{data}{Icon})
				? "--icon '$self->{data}{Icon}'" : '' ;
		}
		elsif ($1 eq '%c') { # name
			# FIXME locale stuff
			$self->{data}{Name};
		}
		elsif ($1 eq '%k') { # desktop file
			exists($self->{file}) ? $self->{file} : '';
		}
		elsif ($1 eq '%v') { # device ?
			$self->{data}{Dev}; # !??? is this correct ?
		}
	}eg;

	return $exec;
}

sub _paths {
	my @paths;
	for (@_) {
		unless (m#^\w+://#)    { push @paths, $_ }
		elsif  (s#^file://+##) { push @paths, $_ }
		else { die "Application can't open remote files" }
	}
	return @paths;
}

sub _uris {
	my @uris;
	for (@_) {
		if (m#^\w+://#) { push @uris, $_ }
		else { push @uris, 'file:///'.File::Spec->rel2abs($_) }
	}
	return @uris;
}
		
1;

__END__

=back

=head1 LIMITATIONS

There is no support for Legacy-Mixed Encoding. Everybody is using utf8 now ... right ?

If you try to exec a remote file with an application that can only handle
files on the local file system we should -according to the spec- download
the file to a temp location. How can this be implemented with an api that
allows control over this process?

This module only reads desktop files at the moment. Write support should
be added to allow people to use it to create new desktop files.
( Make sure that comments are preserved when adding write support. )

=head1 AUTHOR

Jaap Karssenberg (Pardus) E<lt>pardus@cpan.orgE<gt>

Copyright (c) 2005 Jaap G Karssenberg. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<File::BaseDir>,
L<File::MimeInfo::Applications>

L<X11::FreeDesktop::DesktopEntry>

=cut

