use v6.c;
class Hash::Util:ver<0.0.1>:auth<cpan:ELIZABETH> {
    # to create a performant module, we need to resort to some NQP wizardry
    use nqp;

    role LockedHash {
        has int $!lock_keys;
        has int $!lock_values;

        method lock_keys()   { $!lock_keys = 1 }
        method unlock_keys() { $!lock_keys = 0 }

        method lock_values() { $!lock_values = 1 }
        method unlock_values() { $!lock_values = 1 }

        method initialize() { say "initializing"; self }
    }

    proto sub lock_keys(|) is export {*}
    multi sub lock_keys(Map:D \the-hash) {
        the-hash does LockedHash;
        the-hash.initialize;
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
