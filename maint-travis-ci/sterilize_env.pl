#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use tools;

sub no_sterile_warning {
  if ( env_is( 'TRAVIS_PERL_VERSION', '5.8' ) or env_is( 'TRAVIS_PERL_VERSION', '5.10' ) ) {
    diag("\e[31m TREE STERILIZATION IMPOSSIBLE <= 5.10\e[0m");
    diag("\e[32m ... because prior to 5.11.*, dual-life installed to \e[33mprivlib\e[0m");
    diag("\e[32m ... because prior to 5.11.*, \e[33m\@INC\e[32m order was \e[33mprivlib,sitelib\e[0m");
    diag("\e[32m ... whereas after to 5.11.*, \e[33m\@INC\e[32m order is \e[33msitelib,privlib\e[0m");
    diag("\e[32m ... and now most dual-life things simply install to \e[33msitelib\e[0m");
    diag("\e[34m ( However, there are still a few naughty CPAN modules that install to \e[33mprivlib\e[34m )");
    diag(
      "\e[32m but the net effect of this is that installing \e[33mModule::Build 0.4007\e[32m which pulls \e[33mPerl::OSType\e[0m"
    );
    diag("\e[32m and results in  \e[33mPerl::OSType\e[32m being later removed \e[0m");
    diag("\e[32m leaving behind a broken  \e[33mModule::Build 0.4007\e[32m\e[0m");
    diag("\e[34m Set \e[35m MAYBE_BREAK_MODULE_BUILD=1\e[34m if this is ok\e[0m");
    exit 0 unless env_true('MAYBE_BREAK_MODULE_BUILD');
    diag("\e[35m PROCEEDING\e[0m");
  }
}
if ( not env_exists('STERILIZE_ENV') ) {
  diag("\e[31STERILIZE_ENV is not set, skipping, because this is probably Travis's Default ( and unwanted ) target");
  exit 0;
}
if ( not env_true('STERILIZE_ENV') ) {
  diag('STERILIZE_ENV unset or false, not sterilizing');
  exit 0;
}

my $extra_sterile = {
  '5.8' => {
    remove => [ 'Module/Build.pm', 'Module/Build/Base.pm', 'Module/Build/Compat.pm', 'Module/Build/Cookbook.pm', 'autobox.pm' ],
  },
  '5.10' => {
    remove  => ['autobox.pm'],
    install => ['Module::Build~<0.340202'],
  },
  '5.12' => {
    remove  => ['autobox.pm'],
    install => ['Module::Build~<0.3604'],
  },
};

if ( not env_true('TRAVIS') ) {
  diag('Is not running under travis!');
  exit 1;
}

use Config;

my @all_libs  = grep { defined and length and -e $_ } map { $Config{$_} } grep { $_ =~ /(lib|arch)exp$/ } keys %Config;
my @site_libs = grep { defined and length and -e $_ } map { $Config{$_} } grep { $_ =~ /site(lib|arch)exp$/ } keys %Config;

for my $perl_ver ( keys %{$extra_sterile} ) {
  if ( env_is( 'TRAVIS_PERL_VERSION', $perl_ver ) ) {
    diag("Running custom sterilization fixups");
    my $fixups = $extra_sterile->{$perl_ver};
    for my $target ( @{ $fixups->{install} } ) {
      cpanm( '--quiet', '--notest', '--no-man-pages', $target );
    }
    if ( $fixups->{remove} ) {
      diag("Removing Bad things from all Config paths");
      for my $libdir (@all_libs) {
        for my $removal ( @{ $fixups->{remove} } ) {
          my $path = $libdir . '/' . $removal;
          diag("\e[32m ? $path \e[0m");
          if ( -e $path and -f $path ) {
            unlink $path;
            diag("Removed $path");
          }
        }
      }
    }
  }
}
for my $libdir (@site_libs) {
  safe_exec( 'find', $libdir, '-type', 'f', '-delete' );
  safe_exec( 'find', $libdir, '-depth', '-type', 'd', '-delete' );
}
