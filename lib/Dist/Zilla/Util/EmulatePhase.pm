use strict;
use warnings;
package Dist::Zilla::Util::EmulatePhase;

#ABSTRACT: Nasty tools for probing L<< C<Dist::Zilla>'s|Dist::Zilla >> internal state.

use Scalar::Util qw( refaddr );
use Try::Tiny;
use Moose::Autobox;
use Sub::Exporter -setup => {
  exports => [ qw( deduplicate expand_modname get_plugins get_metadata )],
  groups  => [ default => [ qw( -all )]],
};

=method deduplicate

Internal utility that de-duplicates references by ref-addr alone.

  my $array = [];
  is_deeply( [ deduplicate( $array, $array ) ],[ $array ] )

=cut

sub deduplicate {
  my ( @args , %seen, @out ) = @_ ;
  @args->each(sub{
    my ( $index, $item ) = @_ ;
    my $a = refaddr($item);
    @out->push( $item ) unless %seen->exists( $item );
    %seen->put( $item => 1 );
  });
  return @out;
}

=method expand_modname

Internal utility to expand various shorthand notations to full ones.

  expand_modname('-MetaProvider') == 'Dist::Zilla::Role::MetaProvider';
  expand_modname('=MetaNoIndex')  == 'Dist::Zilla::Plugin::MetaNoIndex';

=cut

sub expand_modname {
  ## no critic ( RegularExpressions::RequireDotMatchAnything RegularExpressions::RequireExtendedFormatting RegularExpressions::RequireLineBoundaryMatching )
  my $v = shift;
  $v =~ s/^-/Dist::Zilla::Role::/;
  $v =~ s/^=/Dist::Zilla::Plugin::/;
  return $v;
}

=method get_plugins

Probe Dist::Zilla's plugin registry and get items matching a specification

  my @plugins = get_plugins({
    zilla     => $self->zilla,
    with      => [qw( -MetaProvider -SomethingElse     )],
    skip_with => [qw( -SomethingBadThatIsAMetaProvider )],
    isa       => [qw( =SomePlugin   =SomeOtherPlugin   )],
    skip_isa  => [qw( =OurPlugin                       )],
  });

=cut

sub get_plugins {
  my ( $config ) = @_;
  my $zilla = $config->{zilla};

  my $plugins = $zilla->plugins();

  if ( $config->exists( 'with') ){
    $plugins = $config->at('with')->map(sub{
      my $with = expand_modname(shift);
      return $plugins->grep(sub{ $_->does( $with )  })->flatten;
    });
  }

  if ( $config->exists('skip_with') ){
    $config->at('skip_with')->each(sub{
      my ( $index, $value ) =  @_; 
      my $without = expand_modname($value);
      $plugins = $plugins->grep(sub{ not $_->does($without) });
    });
  }

  if( $config->exists('isa') ){
    $plugins = $config->at('isa')->map(sub{
      my $isa = expand_modname(shift);
      return $plugins->grep(sub{ $_->isa($isa) })->flatten;
    });
  }

  if( $config->exists('skip_isa') ){
    $config->at('skip_isa')->each(sub{
      my ( $index, $value ) =  @_; 
      my $isnt = expand_modname($value);
      $plugins = $plugins->grep(sub{ not $_->isa($isnt) });
    });
  }

  return deduplicate( $plugins->flatten );
}

=method get_metadata

Emulates Dist::Zilla's internal metadata aggregation and does it all again.

  my $metadata = get_metadata({
    $zilla = $self->zilla,
     ... more params to get_plugins ...
     ... ie: ...
     with => [qw( -MetaProvider )],
     isa  => [qw( =MetaNoIndex )],
   });

=cut

sub get_metadata {
  my ( $config ) = @_;
  my @plugins = get_plugins( $config );
  my $meta = {};
  @plugins->each(sub{
    my ( $index, $value ) = @_ ;
    require Hash::Merge::Simple;
    $meta = Hash::Merge::Simple::merge( $meta,  $value->metadata );
  });
  return $meta;
}

1;
