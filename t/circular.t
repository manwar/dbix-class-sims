# vi:sw=2
use strict;
use warnings FATAL => 'all';

use Test::More;
use Test::Deep;
use Test::Exception;
use Test::Warn;

BEGIN {
  {
    package MyApp::Schema::Result::Company;
    use base 'DBIx::Class::Core';
    __PACKAGE__->table('companies');
    __PACKAGE__->add_columns(
      id => {
        data_type => 'int',
        is_nullable => 0,
        is_auto_increment => 1,
        extra       => { unsigned => 1 },
      },
      owner_id => {
        data_type   => 'int',
        is_nullable => 0,
        is_numeric  => 1,
        extra       => { unsigned => 1 },
      },
    );
    __PACKAGE__->set_primary_key('id');
    __PACKAGE__->belongs_to( 'owner' => 'MyApp::Schema::Result::Person' => { "foreign.id" => "self.owner_id" });
    __PACKAGE__->has_many( 'employees' => 'MyApp::Schema::Result::Person' => { "foreign.company_id" => "self.id" } );
  }
  {
    package MyApp::Schema::Result::Person;
    use base 'DBIx::Class::Core';
    __PACKAGE__->table('persons');
    __PACKAGE__->add_columns(
      id => {
        data_type => 'int',
        is_nullable => 0,
        is_auto_increment => 1,
        extra       => { unsigned => 1 },
      },
      company_id => {
        data_type   => 'int',
        is_nullable => 0,
        is_numeric  => 1,
        extra       => { unsigned => 1 },
      },
    );
    __PACKAGE__->set_primary_key('id');
    __PACKAGE__->belongs_to( 'employer' => 'MyApp::Schema::Result::Company' => { "foreign.id" => "self.company_id" } );
    __PACKAGE__->has_many( 'companies' => 'MyApp::Schema::Result::Company' => { "foreign.id" => "self.company_id" } );
  }

  {
    package MyApp::Schema;
    use base 'DBIx::Class::Schema';
    __PACKAGE__->register_class(Company => 'MyApp::Schema::Result::Company');
    __PACKAGE__->register_class(Person => 'MyApp::Schema::Result::Person');
    __PACKAGE__->load_components('Sims');
  }
}

use Test::DBIx::Class -connect_opts => {
  on_connect_do => 'PRAGMA foreign_keys = ON',
}, qw(:resultsets);

{
  Schema->deploy({ add_drop_table => 1 });

  is Company->count, 0, "There are no companies loaded at first";
  is Person->count, 0, "There are no persons loaded at first";

  throws_ok {
    Schema->load_sims(
      {
        Company => [
          {},
        ],
      },
    );
  } qr/expected directed acyclic graph/, "Throws the right exception";

  is Company->count, 0, "No company was added";
  is Person->count, 0, "No person was added";
}

{
  Schema->deploy({ add_drop_table => 1 });

  is Company->count, 0, "There are no companies loaded at first";
  is Person->count, 0, "There are no persons loaded at first";

  lives_ok {
    Schema->load_sims(
      {
        Company => [
          { id => 1, owner_id => 1 },
        ],
        Person => [
          { id => 1, company_id => 1 },
        ],
      }, {
        toposort => {
          skip => {
            Company => [ 'owner' ],
          },
        },
      },
    );
  } "Everything loads ok";

  is Company->count, 1, "One company was added";
  is Person->count, 1, "One person was added";

  cmp_ok Company->first->owner->id, '==', Person->first->id, "Company owner is the person";
  cmp_ok Company->first->id, '==', Person->first->employer->id, "Company is the person's employer";
}

# Follow the unskipped relationship and have the Company be updated
# after the fact.
{
  Schema->deploy({ add_drop_table => 1 });

  is Company->count, 0, "There are no companies loaded at first";
  is Person->count, 0, "There are no persons loaded at first";

  lives_ok {
    Schema->load_sims(
      {
        Person => 1,
      }, {
        toposort => {
          skip => {
            Company => [ 'owner' ],
          },
        },
      },
    );
  } "Everything loads ok";

  is Company->count, 1, "One company was added";
  is Person->count, 1, "One person was added";

  cmp_ok Company->first->owner->id, '==', Person->first->id, "Company owner is the person";
  cmp_ok Company->first->id, '==', Person->first->employer->id, "Company is the person's employer";
}

# Follow the skipped relationship and have the Company be updated
# after the fact.
{
  Schema->deploy({ add_drop_table => 1 });

  is Company->count, 0, "There are no companies loaded at first";
  is Person->count, 0, "There are no persons loaded at first";

  lives_ok {
    Schema->load_sims(
      {
        Company => 1,
      }, {
        toposort => {
          skip => {
            Company => [ 'owner' ],
          },
        },
      },
    );
  } "Everything loads ok";

  is Company->count, 1, "One company was added";
  is Person->count, 1, "One person was added";

  cmp_ok Company->first->owner->id, '==', Person->first->id, "Company owner is the person";
  cmp_ok Company->first->id, '==', Person->first->employer->id, "Company is the person's employer";
}

done_testing;
