requires 'perl', '5.024000';
requires 'Const::Fast';
requires 'Data::Printer';
requires 'HTML::Entities';
requires 'Import::Into';
requires 'JSON';
requires 'Kavorka';
requires 'List::MoreUtils',     0.422;
requires 'List::MoreUtils::XS', 0.422;
requires 'Module::Runtime';
requires 'Moose', 1.99;
requires 'MooseX::MarkAsMethods';
requires 'MooseX::SemiAffordanceAccessor';
requires 'MooseX::StrictConstructor';
requires 'Path::Class';
requires 'Statistics::Lite';
requires 'Text::Trim';
requires 'Unicode::GCString';
requires 'Unicode::LineBreak';
requires 'indirect';

on 'test' => sub {
    requires 'Test::More', '0.98';
};

on 'develop' => sub {
    requires 'App::Ack';
    requires 'PadWalker';
    requires 'Perl::Critic';
    requires 'Perl::Critic';
    requires 'Perl::Critic::Bangs';
    requires 'Perl::Critic::CognitiveComplexity';
    requires 'Perl::Critic::Freenode';
    requires 'Perl::Critic::Lax';
    requires 'Perl::Critic::Moose';
    requires 'Perl::Critic::Moose';
    requires 'Perl::Critic::More';
    requires 'Perl::Critic::Nits';
    requires 'Perl::Critic::PetPeeves::JTRAMMELL ';
    requires 'Perl::Critic::Policy::BuiltinFunctions::ProhibitDeleteOnArrays';
    requires 'Perl::Critic::Policy::BuiltinFunctions::ProhibitReturnOr';
    requires 'Perl::Critic::Policy::References::ProhibitComplexDoubleSigils';
    requires
      'Perl::Critic::Policy::ValuesAndExpressions::ProhibitSingleArgArraySlice';
    requires 'Perl::Critic::Pulp';
    requires 'Perl::Critic::StricterSubs';
    requires 'Perl::Critic::StricterSubs';
    requires 'Perl::Critic::Swift';
    requires 'Perl::Critic::Tics';
    requires 'Perl::Critic::Tics';
    requires 'Perl::Critic::logicLAB';
    requires 'Perl::Tidy';
  }

