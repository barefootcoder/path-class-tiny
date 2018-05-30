package Path::Class::Tiny;

use 5.10.0;
use strict;
use warnings;

# VERSION

use Exporter;
our @EXPORT = qw< path file >;

sub import
{
	no strict 'refs';
	*{ caller . '::dir' } = \&_global_dir if @_ <= 1 or grep { $_ eq 'dir' } @_;
	goto \&Exporter::import;
}


use Carp;
use Module::Runtime qw< require_module >;


use File::Spec ();
use Path::Tiny ();
our @ISA = qw< Path::Tiny >;


sub path
{
	bless Path::Tiny::path(@_), __PACKAGE__;
}

*file = \&path;
sub _global_dir { @_ ? path(@_) : path(Path::Tiny->cwd) }

# just like in Path::Tiny
sub new { shift; path(@_) }
sub child { path(shift->[0], @_) }


# This seemed like a good idea when I originally conceived this class.  Now,
# after further thought, it seems wildly reckless.  Who knows?  I may swing
# back the other way before we're all done.  But, for now, I think we're
# leaving this out, and that may very well end up being a permanent thing.
#
# sub isa
# {
#	my ($obj, $type) = @_;
#	return 1 if $type eq 'Path::Class::File';
#	return 1 if $type eq 'Path::Class::Dir';
#	return 1 if $type eq 'Path::Class::Entity';
#	return $obj->SUPER::isa($type);
# }


# essentially just reblessings
sub parent		{ path( &Path::Tiny::parent   ) }
sub realpath	{ path( &Path::Tiny::realpath ) }

# simple correspondences
*dir		=	\&parent;
*subdir		=	\&child;
*rmtree		=	\&Path::Tiny::remove_tree;

# more complex corresondences
sub cleanup		{ path(shift->canonpath) }
sub open		{ my $io_class = -d $_[0] ? 'IO::Dir' : 'IO::File'; require_module $io_class; $io_class->new(@_) }


# reimplementations

sub dir_list
{
	my $self = shift;
	my @list = ( File::Spec->splitdir($self->parent), $self->basename );

	# The return value of dir_list is remarkably similar to that of splice: it's identical for all
	# cases in list context, and even for one case in scalar context.  So we'll cheat and use splice
	# for most of the cases, and handle the other two scalar context cases specially.
	if (@_ == 0)
	{
		return @list;			# will DTRT regardless of context
	}
	elsif (@_ == 1)
	{
		return wantarray ? splice @list, $_[0] : $list[shift];
	}
	else
	{
		return splice @list, $_[0], $_[1];
	}
}
# components is really just an alias for `dir_list`
*components	=	\&dir_list;


# This is more or less how Path::Class::File does it.
sub slurp
{
	my ($self, %args) = @_;
	my $splitter     = delete $args{split};
	$args{chomp}   //= delete $args{chomped} if exists $args{chomped};
	$args{binmode} //= delete $args{iomode};
	$args{binmode}  =~ s/^<// if $args{binmode};	# remove redundant openmode, if present

	if (wantarray)
	{
		my @data = $self->lines(\%args);
		@data = map { [ split $splitter, $_ ] } @data if $splitter;
		return @data;
	}
	else
	{
		croak "'split' argument can only be used in list context" if $splitter;
		croak "'chomp' argument not implemented in scalar context" if exists $args{chomp};
		return $self->Path::Tiny::slurp(\%args);
	}
}

# A bit trickier, as we have to distinguish between Path::Class::File style,
# which is optional hash + string-or-arrayref, and Path::Tiny style, which is
# optional hashref + string-or-arrayref.  But, since each one's arg hash(ref)
# only accepts a single option, we should be able to fake it fairly simply.
sub spew
{
	my ($self, @data) = @_;
	if ( @data == 3 and $data[0] eq 'iomode' )
	{
		shift @data;
		my $binmode = shift @data;
		$binmode =~ s/^(>>?)//;						# remove redundant openmode, if present
		unshift @data, {binmode => $binmode} if $binmode;
		# if openmode was '>>', redirect to `append`
		return $self->append(@data) if $1 and $1 eq '>>';
	}
	return $self->Path::Tiny::spew(@data);
}


my $_iter;
sub next
{
	$_iter //= Path::Tiny::path(shift)->iterator;
	my $p = $_iter->();
	return $p ? bless $p, __PACKAGE__ : undef $_iter;
}


# new methods

sub ef
{
	my ($self, $other) = @_;
	return $self->realpath eq path($other)->realpath;
}


1;


# ABSTRACT: a Path::Tiny wrapper for Path::Class compatibility
# COPYRIGHT


=head1 SYNOPSIS

    use Path::Class::Tiny;

    # creating Path::Class::Tiny objects
    $dir1 = path("/tmp");
    $dir2 = dir("/home");
    $foo = path("foo.txt");
    $foo = file("bar.txt");

    $subdir = $dir->child("foo");
    $bar = $subdir->child("bar.txt");

    # stringifies as cleaned up path
    $file = path("./foo.txt");
    print $file; # "foo.txt"

    # reading files
    $guts = $file->slurp;
    @lines = $file->slurp;

    # writing files
    $bar->spew( $data );
    $bar->spew( @data );

    # comparing files
    if ( $foo->ef($bar) ) { ... }

    # reading directories
    for ( $dir->children ) { ... }


=head1 DESCRIPTION

What do you do if you started out (Perl) life using L<Path::Class>, but then later on you switched
to L<Path::Tiny>?  Well, one thing you could do is relearn a bunch of things and go change a lot of
existing code.  Or, another thing would be to use Path::Class::Tiny instead.

Path::Class::Tiny is a thin(ish) wrapper around Path::Tiny that (mostly) restores the Path::Class
interface.  Where the two don't conflict, you can do it either way.  Where they do conflict, you use
the Path::Class way.  Except where Path::Class is totally weird, in which case you use the
Path::Tiny way.

Some examples:

=head2 Creating file/dir/path objects

Path::Class likes you to make either a C<file> object or a C<dir> object.  Path::Tiny says that's
silly and you should just make a C<path> object.  Path::Class::Tiny says you can use any of the 3
words you like; all the objects will be the same underneath.

    my $a = file('foo', 'bar');
    my $b = dir('foo', 'bar');
    my $c = path('foo', 'bar');
    say "true" if $a eq $b;         # yep
    say "true" if $b eq $c;         # also yep

=head2 Going up or down the tree

Again, both styles work.

    my $d = dir("foo");
    my $up = $d->dir;               # this works
    $up = $d->parent;               # so does this
    $up = $d->dir->parent;          # sure, why not?
    my $down = $d->child('bar');    # Path::Tiny style
    my $down = $d->subdir('bar');   # Path::Class style

=head2 Slurping files

This mostly works like Path::Class, in that the return value is context-sensitive, and options are
sent as a hash and B<not> as a hashref.

    my $data = $file->slurp;                        # one big string
    my @data = $file->slurp;                        # one element per line
    my @data = $file->slurp(chomp => 1);            # chomp every line
    my @data = $file->slurp(iomode => '<:crlf');    # Path::Class style; works
    my @data = $file->slurp(binmode => ':crlf');    # vaguely Path::Tiny style; also works
    my @data = $file->slurp({binmode => ':crlf'});  # this one doesn't work
    my $data = $file->slurp(chomp => 1);            # neither does this one, because it's weird


=head1 DETAILS

B<This module is still undergoing active development.>  While the general UI is somewhat constrained
by the design goals, specific choices may, and almost certainly will, change.  I think this module
can be useful to you, but for right now I would only use it for personal scripts.

A Path::Class::Tiny C<isa> Path::Tiny, but I<not> C<isa> Path::Class::Entity.  At least not
currently.

Path::Class::Tiny is not entirely a drop-in replacement for Path::Class, and most likely never will
be.  In particular, I have no interest in implementing any of the "foreign" methods.  However, it
should work for most common cases, and, if it doesn't, patches are welcome.

Performance of Path::Class::Tiny should be comparable to Path::Tiny.  Again, if it's not, please let
me know.

The POD is somewhat impoverished at the moment.  Hopefully that will improve over time.  Again,
patches welcomed.


=head1 NEW METHODS

=head2 ef

Are you tired of trying to remember which method (or combination of methods) you have to call to
verify that two files are actually the same file, where one path might be relative and the other
absolute, or one might be a symlink to the other, or one might be a completely different path but
one directory somewhere in the middle is really a symlink to a directory in the middle of the other
path so they wind up being the same path, really?  Yeah, me too.  In C<bash>, this is super easy:

    if [[ $file1 -ef $file2 ]]

Well, why shouldn't it be easy in Perl too?  Okay, now it is:

    my $file1 = path($whatever);
    if ( $file1->ef($file2) )

While C<$file1> must obviously be a Path::Class::Tiny, C<$file2> can be another Path::Class::Tiny
object, or a Path::Class::Entity, or a Path::Tiny, or just a bare string.  Most anything should
work, really.  Do note that both files must actually exist in the filesystem though.  It's also okay
for both to be exactly the same object:

    if ( $file1->ef($file1) )   # always true
