use v6.c;

role LockedHash {
    has int $!lock_hash;
    has int $!lock_keys;

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

    method lock_hash()   { $!lock_hash = 1; self }
    method unlock_hash() { $!lock_hash = 1; self }

    method lock_keys(@keys)   {
        if @keys {
            self.ASSIGN-KEY($_,Mu,True) unless self.EXISTS-KEY($_) for @keys;

            # there were keys in the hash that weren't specified
            missed( (self (-) @keys).keys ) if self.elems > @keys;
        }

        $!lock_keys = 1;
        self
    }
    method unlock_keys() { $!lock_keys = 0; self }

    method lock_value(\key) {
        self.BIND-KEY(key,self.AT-KEY(key,True)<>,True);
        self
    }
    method unlock_value(\key) {
        my \value := self.AT-KEY(key,True);
        self.DELETE-KEY(key,True);
        self.ASSIGN-KEY(key,value,True);
        self
    }

    multi method AT-KEY(::?CLASS:D: \key, \ok) is raw {
        callwith(key)
    }
    multi method AT-KEY(::?CLASS:D: \key) is raw is default {
        self.EXISTS-KEY(key)
          ?? $!lock_hash               # key exists
            ?? callsame()<>              # and locked hash, so decont
            !! callsame()                # and NO locked hash, so pass on
          !! $!lock_keys               # key does NOT exist
            ?? disallowed(key)           # and locked keys, so forget it
            !! callsame()                # and NO locked keys, so pass on
    }

    multi method ASSIGN-KEY(::?CLASS:D: \key, \value, \ok) is raw {
        callwith(key,value)
    }
    multi method ASSIGN-KEY(::?CLASS:D: \key, \value) is raw is default {
        self.EXISTS-KEY(key)
          ?? $!lock_hash               # key exists
            ?? readonly(key)             # and locked hash, so forget it
            !! callsame()                # and NO locked hash, so pass on
          !! $!lock_keys               # key does NOT exist
            ?? disallowed(key)           # and locked keys, so forget it
            !! callsame()                # and NO locked keys, so pass on
    }

    multi method BIND-KEY(::?CLASS:D: \key, \value, \ok) is raw {
        callwith(key,value)
    }
    multi method BIND-KEY(::?CLASS:D: \key, \value) is raw is default {
        self.EXISTS-KEY(key)
          ?? $!lock_hash               # key exists
            ?? readonly(key)             # and locked hash, so forget it
            !! callsame()                # and NO locked hash, so pass on
          !! $!lock_keys               # key does NOT exist
            ?? disallowed(key)           # and locked keys, so forget it
            !! callsame()                # and NO locked keys, so pass on
    }
}

class Hash::Util:ver<0.0.1>:auth<cpan:ELIZABETH> {

    proto sub lock_hash(|) is export(:all) {*}
    multi sub lock_hash(Associative:D \the-hash) {
        (the-hash does LockedHash).lock_hash
    }
    multi sub lock_hash(LockedHash:D \the-hash) is default {
        the-hash.lock_hash
    }

    proto sub unlock_hash(|) is export(:all) {*}
    multi sub unlock_hash(Associative:D \the-hash) {
        (the-hash does LockedHash).unlock_hash
    }
    multi sub unlock_hash(LockedHash:D \the-hash) is default {
        the-hash.unlock_hash
    }

    proto sub lock_keys(|) is export(:all) {*}
    multi sub lock_keys(Associative:D \the-hash, *@keys) {
        (the-hash does LockedHash).lock_keys(@keys)
    }
    multi sub lock_keys(LockedHash:D \the-hash, *@keys) is default {
        the-hash.lock_keys(@keys)
    }

    proto sub unlock_keys(|) is export(:all) {*}
    multi sub unlock_keys(Associative:D \the-hash) {
        (the-hash does LockedHash).unlock_keys
    }
    multi sub unlock_keys(LockedHash:D \the-hash) is default {
        the-hash.unlock_keys
    }

    proto sub lock_value(|) is export(:all) {*}
    multi sub lock_value(Associative:D \the-hash, \key) {
        (the-hash does LockedHash).lock_value(key)
    }
    multi sub lock_value(LockedHash:D \the-hash, \key) is default {
        the-hash.lock_value(key)
    }

    proto sub unlock_value(|) is export(:all) {*}
    multi sub unlock_value(Associative:D \the-hash, \key) {
        (the-hash does LockedHash).unlock_value(key)
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
