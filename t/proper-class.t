use Test::Most 0.25;

use Path::Class::Tiny;


my $CLASS = 'Path::Class::Tiny';

my $dir = tempdir->child('sub');
$dir->mkpath or die("can't make dir: $dir");
my $file = $dir->child('f');
$file->touch;


isa_ok $dir, $CLASS, "base object [sanity check]";
isa_ok $dir->parent, $CLASS, "obj returned by parent()";
isa_ok $dir->dirname, $CLASS, "obj returned by dirname()";
isa_ok $dir->dir, $CLASS, "obj returned by dir()";
isa_ok $dir->child('foo'), $CLASS, "obj returned by child()";
isa_ok $dir->file('foo'), $CLASS, "obj returned by file()";
isa_ok $dir->subdir('foo'), $CLASS, "obj returned by subdir()";
isa_ok $dir->realpath, $CLASS, "obj returned by realpath()";

map { isa_ok $_, $CLASS, "obj returned by children()" } $dir->children;


done_testing;
