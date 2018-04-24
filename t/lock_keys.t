use v6.c;
use Test;
use Hash::Util <lock_keys unlock_keys>;

my %h = a => 42, b => 666;
dd %h.AT-KEY("c");
dd lock_keys(%h);

dd %h.AT-KEY("a") = 77;

dd %h.AT-KEY("c");
dd unlock_keys(%h);
dd %h.AT-KEY("c") = 89;
dd %h;

# vim: ft=perl6 expandtab sw=4
