use v6.c;

role LockedHash {
    has int $!lock_hash;
    has int $!lock_keys;
    has $!AT-KEY;
    has $!ASSIGN-KEY;
    has $!BIND-KEY;
    has $!DELETE-KEY;

    sub disallowed($key --> Nil) is hidden-from-backtrace {
       die "Attempt to access disallowed key '$key' in a restricted hash"
    }
    sub readonly($key --> Nil) is hidden-from-backtrace {
       die "Modification of a read-only value attempted"
    }
    sub missed(@missed --> Nil) is hidden-from-backtrace {
       die @missed == 1
         ?? "Hash has key '@missed[0]' which is not in the new key set"
         !! "Hash has keys '@missed.join(q/','/)' which are not in the new key set"
    }

    submethod initialize(@candidates) {
        $!AT-KEY     := @candidates[0];
        $!ASSIGN-KEY := @candidates[1];
        $!BIND-KEY   := @candidates[2];
        $!DELETE-KEY := @candidates[3];
        self
    }

    method lock_hash()   { $!lock_hash = 1; self }
    method unlock_hash() { $!lock_hash = 1; self }

    method lock_keys(@keys)   {
        if @keys {
            $!ASSIGN-KEY(self,$_,Mu) unless self.EXISTS-KEY($_) for @keys;

            # there were keys in the hash that weren't specified
            missed( (self (-) @keys).keys ) if self.elems > @keys;
        }

        $!lock_keys = 1;
        self
    }
    method unlock_keys() { $!lock_keys = 0; self }

    method lock_value(\key) {
        $!BIND-KEY(self,key,$!AT-KEY(self,key)<>);
        self
    }
    method unlock_value(\key) {
        my \value := $!AT-KEY(self,key);
        $!DELETE-KEY(self,key);
        $!ASSIGN-KEY(self,key,value);
        self
    }

    method AT-KEY(\key) is raw {
        self.EXISTS-KEY(key)
          ?? $!lock_hash                   # key exists
            ?? $!AT-KEY(self,key)<>          # and locked hash, so decont
            !! $!AT-KEY(self,key)            # and NO locked hash, so pass on
          !! $!lock_keys                   # key does NOT exist
            ?? disallowed(key)               # and locked keys, so forget it
            !! $!AT-KEY(self,key)            # and NO locked keys, so pass on
    }

    method ASSIGN-KEY(\key, \value) is raw {
        self.EXISTS-KEY(key)
          ?? $!lock_hash                   # key exists
            ?? readonly(key)                 # and locked hash, so forget it
            !! $!ASSIGN-KEY(self,key,value)  # and NO locked hash, so pass on
          !! $!lock_keys                   # key does NOT exist
            ?? disallowed(key)               # and locked keys, so forget it
            !! $!ASSIGN-KEY(self,key,value)  # and NO locked keys, so pass on
    }

    method BIND-KEY(\key, \value) is raw {
        self.EXISTS-KEY(key)
          ?? $!lock_hash                   # key exists
            ?? readonly(key)                 # and locked hash, so forget it
            !! $!BIND-KEY(self,key,value)    # and NO locked hash, so pass on
          !! $!lock_keys                   # key does NOT exist
            ?? disallowed(key)               # and locked keys, so forget it
            !! $!BIND-KEY(self,key,value)    # and NO locked keys, so pass on
    }
}

class Hash::Util:ver<0.0.1>:auth<cpan:ELIZABETH> {

    sub candidates(\the-hash) {
        (
          the-hash.can(    'AT-KEY').head,
          the-hash.can('ASSIGN-KEY').head,
          the-hash.can(  'BIND-KEY').head,
          the-hash.can('DELETE-KEY').head,
        )
    }

    proto sub lock_hash(|) is export(:all) {*}
    multi sub lock_hash(Associative:D \the-hash) {
        my @candidates := candidates(the-hash);
        (the-hash does LockedHash).initialize(@candidates).lock_hash
    }
    multi sub lock_hash(LockedHash:D \the-hash) is default {
        the-hash.lock_hash
    }

    proto sub unlock_hash(|) is export(:all) {*}
    multi sub unlock_hash(Associative:D \the-hash) {
        my @candidates := candidates(the-hash);
        (the-hash does LockedHash).initialize(@candidates).unlock_hash
    }
    multi sub unlock_hash(LockedHash:D \the-hash) is default {
        the-hash.unlock_hash
    }

    proto sub lock_keys(|) is export(:all) {*}
    multi sub lock_keys(Associative:D \the-hash, *@keys) {
        my @candidates := candidates(the-hash);
        (the-hash does LockedHash).initialize(@candidates).lock_keys(@keys)
    }
    multi sub lock_keys(LockedHash:D \the-hash, *@keys) is default {
        the-hash.lock_keys(@keys)
    }

    proto sub unlock_keys(|) is export(:all) {*}
    multi sub unlock_keys(Associative:D \the-hash) {
        my @candidates := candidates(the-hash);
        (the-hash does LockedHash).initialize(@candidates).unlock_keys
    }
    multi sub unlock_keys(LockedHash:D \the-hash) is default {
        the-hash.unlock_keys
    }

    proto sub lock_value(|) is export(:all) {*}
    multi sub lock_value(Associative:D \the-hash, \key) {
        my @candidates := candidates(the-hash);
        (the-hash does LockedHash).initialize(@candidates).lock_value(key)
    }
    multi sub lock_value(LockedHash:D \the-hash, \key) is default {
        the-hash.lock_value(key)
    }

    proto sub unlock_value(|) is export(:all) {*}
    multi sub unlock_value(Associative:D \the-hash, \key) {
        my @candidates := candidates(the-hash);
        (the-hash does LockedHash).initialize(@candidates),unlock_value(key)
    }
    multi sub unlock_value(LockedHash:D \the-hash, \key) is default {
        the-hash.unlock_value(key)
    }
}

sub EXPORT(*@args, *%_) {

    if @args {
        my $imports := Map.new( |(EXPORT::all::{ @args.map: '&' ~ * }:p) );
        if $imports != @args {
            die "Hash::Util doesn't know how to export: "
              ~ @args.grep( { !$imports{$_} } ).join(', ')
        }
        $imports
    }
    else {
        Map.new
    }
}

=begin pod

=head1 NAME

Hash::Util - Port of Perl 5's Hash::Util 0.22

=head1 SYNOPSIS

  use Hash::Util;

=head1 DESCRIPTION

Hash::Util is ...

=head1 SEE ALSO

L<Scalar::Util>, L<List::Util>

=head1 AUTHOR

Elizabeth Mattijsen <liz@wenzperl.nl>

Source can be located at: https://github.com/lizmat/Hash-Util . Comments and
Pull Requests are welcome.

=head1 COPYRIGHT AND LICENSE

Copyright 2018 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

Re-imagined from the Perl 5 version as part of the CPAN Butterfly Plan. Perl 5
version originally developed by the Perl 5 Porters, subsequently maintained
by Steve Hay.

=end pod

# vim: ft=perl6 expandtab sw=4
