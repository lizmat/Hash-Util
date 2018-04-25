use v6.c;
use Test;
use Hash::Util <lock_value unlock_value>;

plan 13;

my %hash = a => 42, b => 666;

ok lock_value(%hash,"a") =:= %hash, 'does lock_value return %hash';

ok %hash<a>:exists, 'does "a" still exist';
is %hash<a>, 42, 'does "a" still have the same value';
ok %hash<b>:exists, 'does "b" still exist';
is %hash<b>, 666, 'does "b" still have the same value';
is (%hash<e> = 271), 271, 'can we assign a new key "e"?';

ok unlock_value(%hash,"a") =:= %hash, 'does unlock_value return %hash';
is %hash<a>, 42, 'does "a" still have the same value after unlock';
is (%hash<a> = 84), 84, 'can we change the value of "a"?';

ok lock_value(%hash,"a") =:= %hash, 'does lock_value return %hash';
my $caught = 0;
{ %hash<a> = 77; CATCH { default { ++$caught } } }
is $caught, 1, 'did we get an exception for attempting to change value of "a"?';
is %hash<a>, 84, 'did the assignment actually fail';
is %hash<a>:delete, 84, 'can we remove "a"?';

# vim: ft=perl6 expandtab sw=4
