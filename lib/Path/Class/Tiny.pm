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
sub parent	{ path( &Path::Tiny::parent ) }

# simple correspondences
*dir		=	\&Path::Tiny::parent;
*subdir		=	\&child;
*rmtree		=	\&Path::Tiny::remove_tree;

# more complex corresondences
sub cleanup		{ path(shift->canonpath) }
sub open		{ my $io_class = -d $_[0] ? 'IO::Dir' : 'IO::File'; require_module $io_class; $io_class->new(@_) }


# reimplementations

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

__END__
