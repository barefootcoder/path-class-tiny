use Test::Most 0.25;

use Path::Class::Tiny;

use Path::Tiny ();
use Module::Runtime qw< module_notional_filename >;

sub loads_ok(&$$);				# see below


my $dir = path(Path::Tiny->tempdir)->child('dates');
$dir->mkpath or die("can't make dir: $dir");

my $a = $dir->child('a');
$a->touch;

loads_ok { $a->mtime } mtime => 'Date::Easy::Datetime';

my $dt = Date::Easy::Datetime->new(2001, 2, 3, 4, 5, 6);
warning_is { $a->touch($dt) } undef, "can send `touch` a datetime object";
isa_ok $a->mtime, 'Date::Easy::Datetime' => 'return from mtime';
is $a->mtime, $dt, "`mtime` returns same datetime sent to `touch`";


done_testing;


# stolen from: https://github.com/barefootcoder/common/blob/master/perl/myperl/t/autoload.t
sub loads_ok (&$$)
{
	my ($sub, $function, $module) = @_;
	my $module_key = module_notional_filename($module);

	is exists $INC{$module_key}, '', "haven't yet loaded: $module";
	lives_ok { $sub->() } "can call $function()";
	is exists $INC{$module_key}, 1, "have now loaded: $module";
}
