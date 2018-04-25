use v6.c;

#---- role to mix into Associative class ---------------------------------------
role LockedHash {
    has int $!lock_hash;
    has int $!lock_keys;

    #---- original Associative candidates --------------------------------------
    has $!EXISTS-KEY;
    has $!AT-KEY;
    has $!ASSIGN-KEY;
    has $!BIND-KEY;
    has $!DELETE-KEY;

    #---- shortcuts to exceptions ----------------------------------------------
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
    sub delete($key --> Nil) is hidden-from-backtrace {
       die "Attempt to delete readonly key '$key' from a restricted hash"
    }

    #---- initialization -------------------------------------------------------
    my constant HIDDEN := Mu.new
      but role { method defined { False } };     # sentinel for hidden keys

    submethod initialize(
      $!EXISTS-KEY,$!AT-KEY,$!ASSIGN-KEY,$!BIND-KEY,$!DELETE-KEY
    ) {
        self
    }

    #---- standard Associative interface ---------------------------------------
    method EXISTS-KEY(\key) {
        use nqp;  # we need nqp::decont here for some reason
        $!EXISTS-KEY(self,key) && !(nqp::decont($!AT-KEY(self,key)) =:= HIDDEN)
    }
    method AT-KEY(\key) is raw {
        $!EXISTS-KEY(self,key)
          ?? $!lock_hash                   # key exists
            ?? $!AT-KEY(self,key)<>          # and locked hash, so decont
            !! $!AT-KEY(self,key)            # and NO locked hash, so pass on
          !! $!lock_keys                   # key does NOT exist
            ?? disallowed(key)               # and locked keys, so forget it
            !! $!AT-KEY(self,key)            # and NO locked keys, so pass on
    }

    method ASSIGN-KEY(\key, \value) is raw {
        $!EXISTS-KEY(self,key)
          ?? $!lock_hash                   # key exists
            ?? readonly(key)                 # and locked hash, so forget it
            !! $!ASSIGN-KEY(self,key,value)  # and NO locked hash, so pass on
          !! $!lock_keys                   # key does NOT exist
            ?? disallowed(key)               # and locked keys, so forget it
            !! $!ASSIGN-KEY(self,key,value)  # and NO locked keys, so pass on
    }

    method BIND-KEY(\key, \value) is raw {
        $!EXISTS-KEY(self,key)
          ?? $!lock_hash                   # key exists
            ?? readonly(key)                 # and locked hash, so forget it
            !! $!BIND-KEY(self,key,value)    # and NO locked hash, so pass on
          !! $!lock_keys                   # key does NOT exist
            ?? disallowed(key)               # and locked keys, so forget it
            !! $!BIND-KEY(self,key,value)    # and NO locked keys, so pass on
    }

    method DELETE-KEY(\key) is raw {
        $!EXISTS-KEY(self,key)
          ?? $!lock_hash || $!lock_keys    # key exists
            ?? delete(key)                   # and locked hash/keys, forget it
            !! $!DELETE-KEY(self,key)        # and NO locked hash, so pass on
          !! Nil                           # key does NOT exist
    }

    #---- behaviour modifiers --------------------------------------------------
    method lock_hash()   { $!lock_hash = 1; self }
    method unlock_hash() { $!lock_hash = 0; self }

    method lock_keys(@keys,:$plus)   {
        if @keys {
            $!ASSIGN-KEY(self,$_,HIDDEN) unless $!EXISTS-KEY(self,$_) for @keys;

            unless $plus {
                missed( (self (-) @keys).keys ) if self.elems > @keys;
            }
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

    #---- introspection --------------------------------------------------------
    method hash_locked()   {  so $!lock_hash }
    method hash_unlocked() { not $!lock_hash }

    method legal_keys() { self.keys.List }
    method hidden_keys() { self.keys.grep({ .value<> =:= HIDDEN }).List }
    method all_keys(\existing,\hidden) {
        .value<> =:= HIDDEN ?? hidden.push(.key) !! existing.push(.key)
          for self.pairs;
        self
    }
}

#---- actual module with exportable subs ---------------------------------------
module Hash::Util:ver<0.0.1>:auth<cpan:ELIZABETH> {

    #---- helper subs ----------------------------------------------------------
    my List %candidates;
    my $lock = Lock.new;

    sub candidates(\the-hash) {
        $lock.protect: {
            %candidates{the-hash.^name} //= (
              the-hash.can('EXISTS-KEY').head,
              the-hash.can(    'AT-KEY').head,
              the-hash.can('ASSIGN-KEY').head,
              the-hash.can(  'BIND-KEY').head,
              the-hash.can('DELETE-KEY').head,
            )
        }
    }

    #---- lock_hash / unlock_hash ----------------------------------------------
    our proto sub lock_hash(|) is export(:all) {*}
    multi sub lock_hash(Associative:D \the-hash) {
        my @candidates := candidates(the-hash);
        (the-hash does LockedHash).initialize(|@candidates).lock_hash
    }
    multi sub lock_hash(LockedHash:D \the-hash) is default {
        the-hash.lock_hash
    }
    our constant &lock_hashref is export(:all) = &lock_hash;

    our proto sub unlock_hash(|) is export(:all) {*}
    multi sub unlock_hash(Associative:D \the-hash) {
        my @candidates := candidates(the-hash);
        (the-hash does LockedHash).initialize(|@candidates).unlock_hash
    }
    multi sub unlock_hash(LockedHash:D \the-hash) is default {
        the-hash.unlock_hash
    }
    our constant &unlock_hashref is export(:all) = &unlock_hash;

    #---- lock_hash_recurse / unlock_hash_recurse ------------------------------
    our proto sub lock_hash_recurse(|) is export(:all) {*}
    multi sub lock_hash_recurse(Associative:D \the-hash) {
        my @candidates := candidates(the-hash);
        (the-hash does LockedHash).initialize(|@candidates).lock_hash_recurse
    }
    multi sub lock_hash_recurse(LockedHash:D \the-hash) is default {
        lock_hash_recurse($_) if $_ ~~ Associative for the-hash.values;
        the-hash.lock_hash
    }
    our constant &lock_hashref_recurse is export(:all) = &lock_hash_recurse;

    our proto sub unlock_hash_recurse(|) is export(:all) {*}
    multi sub unlock_hash_recurse(Associative:D \the-hash) {
        my @candidates := candidates(the-hash);
        (the-hash does LockedHash).initialize(|@candidates).unlock_hash_recurse
    }
    multi sub unlock_hash_recurse(LockedHash:D \the-hash) is default {
        unlock_hash_recurse($_) if $_ ~~ LockedHash for the-hash.values;
        the-hash.unlock_hash
    }
    our constant &unlock_hashref_recurse is export(:all) = &unlock_hash_recurse;

    #---- lock_keys / lock_keys_plus / unlock_keys -----------------------------
    our proto sub lock_keys(|) is export(:all) {*}
    multi sub lock_keys(Associative:D \the-hash, *@keys) {
        my @candidates := candidates(the-hash);
        (the-hash does LockedHash).initialize(|@candidates).lock_keys(@keys)
    }
    multi sub lock_keys(LockedHash:D \the-hash, *@keys) is default {
        the-hash.lock_keys(@keys)
    }
    our constant &lock_ref_keys is export(:all) = &lock_keys;

    our proto sub lock_keys_plus(|) is export(:all) {*}
    multi sub lock_keys_plus(Associative:D \the-hash, *@keys) {
        my @candidates := candidates(the-hash);
        (the-hash does LockedHash)
          .initialize(|@candidates).lock_keys(@keys,:plus)
    }
    multi sub lock_keys_plus(LockedHash:D \the-hash, *@keys) is default {
        the-hash.lock_keys_plus(@keys,:plus)
    }
    our constant &lock_ref_keys_plus is export(:all) = &lock_keys_plus;

    our proto sub unlock_keys(|) is export(:all) {*}
    multi sub unlock_keys(Associative:D \the-hash) {
        my @candidates := candidates(the-hash);
        (the-hash does LockedHash).initialize(|@candidates).unlock_keys
    }
    multi sub unlock_keys(LockedHash:D \the-hash) is default {
        the-hash.unlock_keys
    }
    our constant &unlock_ref_keys is export(:all) = &unlock_keys;

    #---- lock_value / unlock_value --------------------------------------------
    our proto sub lock_value(|) is export(:all) {*}
    multi sub lock_value(Associative:D \the-hash, \key) {
        my @candidates := candidates(the-hash);
        (the-hash does LockedHash).initialize(|@candidates).lock_value(key)
    }
    multi sub lock_value(LockedHash:D \the-hash, \key) is default {
        the-hash.lock_value(key)
    }
    our constant &lock_ref_value is export(:all) = &lock_value;

    our proto sub unlock_value(|) is export(:all) {*}
    multi sub unlock_value(Associative:D \the-hash, \key) {
        my @candidates := candidates(the-hash);
        (the-hash does LockedHash).initialize(|@candidates),unlock_value(key)
    }
    multi sub unlock_value(LockedHash:D \the-hash, \key) is default {
        the-hash.unlock_value(key)
    }
    our constant &unlock_ref_value is export(:all) = &unlock_value;

    #---- hash_locked / hash_unlocked ------------------------------------------
    our proto sub hash_locked(|) is export(:all) {*}
    multi sub hash_locked(Associative:D \the-hash) {
        my @candidates := candidates(the-hash);
        (the-hash does LockedHash).initialize(|@candidates).hash_locked
    }
    multi sub hash_locked(LockedHash:D \the-hash) is default {
        the-hash.hash_locked
    }
    our constant &hashref_locked is export(:all) = &hash_locked;

    our proto sub hash_unlocked(|) is export(:all) {*}
    multi sub hash_unlocked(Associative:D \the-hash) {
        my @candidates := candidates(the-hash);
        (the-hash does LockedHash).initialize(|@candidates).hash_unlocked
    }
    multi sub hash_unlocked(LockedHash:D \the-hash) is default {
        the-hash.hash_unlocked
    }
    our constant &hashref_unlocked is export(:all) = &hash_unlocked;

    #---- introspection --------------------------------------------------------
    our proto sub legal_keys(|) is export(:all) {*}
    multi sub legal_keys(Associative:D \the-hash) {
        the-hash.keys.List
    }
    multi sub legal_keys(LockedHash:D \the-hash) is default {
        the-hash.legal_keys
    }
    our constant &legal_ref_keys is export(:all) = &legal_keys;

    our proto sub hidden_keys(|) is export(:all) {*}
    multi sub hidden_keys(Associative:D \the-hash) {
        ()
    }
    multi sub hidden_keys(LockedHash:D \the-hash) is default {
        the-hash.hidden_keys
    }
    our constant &hidden_ref_keys is export(:all) = &hidden_keys;

    our proto sub all_keys(|) is export(:all) {*}
    multi sub all_keys(Associative:D \the-hash,\existing,\hidden) {
        existing = the-hash.keys;
        hidden = ();
        the-hash
    }
    multi sub all_keys(LockedHash:D \the-hash,\existing,\hidden) is default {
        the-hash.all_keys(existing,hidden)
    }
    our constant &all_ref_keys is export(:all) = &all_keys;
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
