#!/usr/bin/env perl
use ExtUtils::MakeMaker;
WriteMakefile(
  PREREQ_PM => {
    'Mojolicious' => '5.33',
    'Data-ICal'   => '0.21',
    'File::Spec'  => '3.47',
  }
);
