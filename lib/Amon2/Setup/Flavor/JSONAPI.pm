use strict;
use warnings;
use utf8;

package Amon2::Setup::Flavor::JSONAPI;
use parent qw(Amon2::Setup::Flavor);

sub run {
    my ($self) = @_;

    require Amon2;

    $self->create_cpanfile({
        'Log::Minimal' => 0,
        'Path::Class' => 0,
        'Class::Accessor::Lite' => 0,
        'Redis' => 0,
        'Redis::Key' => 0,
        'Redis::Namespace' => 0,
        'Data::Validator' => 0,
        'Data::Validator::Recursive' => 0,
        'IPC::Cmd' => 0,
        'IPC::Run' => 0,
        'Sub::Retry' => 0,
        'Try::Tiny' => 0,
        'Parallel::Prefork' => 0,
        'DBI' => 0,
        'DBIx::QueryLog' => 0,
        'DBD::mysql' => 0,
        'Daiku' => 0,
    });


    $self->write_file('API.md', <<'...');
# API Specification

<!-- fixme M-x markdown-toc-generate-toc -->

## 共通仕様

## User

### Attributes

| Name | Type | Description | Example |
| ------- | ------- | ------- | ------- |
| **id** | *integer* | ユーザーID | `31` |
| **name** | *string* | ユーザー名 | `"hirose31"` |

### User Info

ユーザー情報を返す

```
GET /user/{USER_NAME}
```

#### Response Example

```
HTTP/1.1 200 OK
```

```json
{
  "id": 31,
  "name": "hirose31"
}
```
...

    $self->write_file('config/myprod.pl', <<'...');
use Path::Class;

my $root_dir = file(__FILE__)->parent->parent->resolve;
my $data_dir = $root_dir->subdir('var');

my $dbuser     = q{user};
my $dbpass     = q{password};
my $dbhost     = q{hostname};
my $dbdatabase = q{database};

+{
    'data_dir' => $data_dir->stringify,
    'maintenance_file' => '/tmp/maintenance',
    # 運用用の更新APIを許可するCIDR
    'allow_from' => c_addr(['10.0.0.0/8', '172.16.0.0/12']),
    'DBI' => [
        "dbi:mysql:database=$dbdatabase;host=$dbhost",
        $dbuser,
        $dbpass,
        {
            AutoCommit           => 1,
            PrintError           => 0,
            RaiseError           => 1,
            ShowErrorStatement   => 1,
            AutoInactiveDestroy  => 1,
            mysql_auto_reconnect => 0,
            mysql_enable_utf8    => 1,
            Callbacks => {
                connected => sub {
                    $_[0]->do('SET NAMES utf8');
                    return;
                },
            },
        },
    ],
    'redis' => {
        server => 'redis.my.local:6379',
    },
};
...

    $self->write_file('lib/<<PATH>>.pm', <<'...');
package <% $module %>;

use strict;
use warnings;
use 5.010_000;
use utf8;

use version; our $VERSION = version->declare('v1.0.0');

use Amon2::Config::Simple;
use Log::Minimal;
use Path::Class;

use <% $module %>::Redis;
use <% $module %>::Util;

use parent qw/Amon2/;
# Enable project local mode.
__PACKAGE__->make_local_context();

__PACKAGE__->load_plugins(
    '+<% $module %>::Plugin::Model',
    '+<% $module %>::Plugin::DataValidator',
);

if ($ENV{RUN_MODE} && $ENV{RUN_MODE} eq 'development') {
    eval q!
      use DBIx::QueryLog;
      $ENV{LM_DEBUG} = 1;
      $DBIx::QueryLog::OUTPUT = sub {
        my %p = @_;
        debugf("%s", $p{message});
      };
    !;
    warnf($@) if $@;
}

sub load_config {
    my $c = shift;

    my $config = Amon2::Config::Simple->load($c, {
        environment => $c->mode_name || 'development',
    });

    if ($ENV{TEST_REDIS}) {
        # connect to Test::RedisServer
        $config->{redis} = {
            $ENV{TEST_REDIS} =~ m{^/} ? (sock => $ENV{TEST_REDIS}) : (server => $ENV{TEST_REDIS}),
        };
    }

    debugf 'config: %s', ddf($config);
    debugf 'data_dir: %s', $config->{data_dir};
    dir($config->{data_dir})->mkpath(0, oct(2775));

    return $config;
}

sub redis {
    my $c = shift;
    if (!exists $c->{redis}) {
        my $conf = $c->config->{redis}
            or die "Missing configuration about Redis";
        # 120 秒まで、1秒ごとに再接続を試行
        $conf->{reconnect} = 120;
        $conf->{every}     = 1_000_000;
        $c->{redis} = <% $module %>::Redis->new($conf);
    }
    $c->{redis};
}

1;

__END__

=head1 NAME

<% $module %> - <% $module %>

=head1 DESCRIPTION

This is a main context class for <% $module %>

=head1 AUTHOR

<% $module %> authors.
...


    $self->write_file('lib/<<PATH>>/API.pm', <<'...');
package <% $module %>::API;

use strict;
use warnings;
use 5.010_000;
use utf8;

use parent qw/<% $module %> Amon2::Web/;

use File::Spec;
use Log::Minimal;
use JSON 2 qw(encode_json decode_json);
use Try::Tiny;
use Encode;

# dispatcher
use <% $module %>::API::Dispatcher;
sub dispatch {
    return (<% $module %>::API::Dispatcher->dispatch($_[0]) or die "response is not generated");
}

# load plugins
__PACKAGE__->load_plugins(
    '+<% $module %>::Plugin::Web::Session',
    '+<% $module %>::Plugin::Web::JSON',
);

# setup view
use <% $module %>::API::View;
{
    sub create_view {
        my $view = <% $module %>::API::View->make_instance(__PACKAGE__);
        no warnings 'redefine';
        *<% $module %>::API::create_view = sub { $view }; # Class cache.
        $view
    }
}

# for your security
__PACKAGE__->add_trigger(
    BEFORE_DISPATCH => sub {
        my($c) = @_;

        my $ua = $c->req->user_agent;
        debugf 'ua: %s', $ua;

        ### 特定の UA の場合はここで処理できる。
        ### 古いバージョンのだったらエラーを返すとか。
        # if ($ua =~ /^Furl/) {
        #     my $res = $c->render_json({message => 'yyyyyyyyay!'});
        #     return $res;
        # }
    },
    AFTER_DISPATCH  => sub {
        my($c, $res) = @_;

        # http://blogs.msdn.com/b/ie/archive/2008/07/02/ie8-security-part-v-comprehensive-protection.aspx
        $res->header( 'X-Content-Type-Options' => 'nosniff' );

        # http://blog.mozilla.com/security/2010/09/08/x-frame-options/
        $res->header( 'X-Frame-Options' => 'DENY' );

        # Cache control.
        $res->header( 'Cache-Control' => 'private' );
    },
);

sub parse_json_qs_request {
    my $c = shift;

    my $req = $c->req;

    my $param = {};

    if ($req->content_type and lc($req->content_type) eq 'application/json') {
        my $content = $req->content || '{}';
        $param = try {
            decode_json($content);
        } catch {
            warnf("%s: %s", $_, $content);
            return;
        };
        return unless $param;
    } else {
        my @keys = $req->param;
        for my $key (@keys) {
            next if $key eq 'pretty';
            my $val = $req->param($key);
            if ($val =~ /^[[{]/) {
                $val = try {
                    decode_json($val);
                } catch {
                    warnf("%s: %s", $_, $val);
                    return;
                };
                return unless $val;
            }
            my $pkey = $key;
            $pkey =~ s/\[[0-9]+\]$//;
            if ($param->{$pkey}) {
                if (ref($param->{$pkey}) ne 'ARRAY') {
                    $param->{$pkey} = [$param->{$pkey}];
                }
                push @{ $param->{$pkey} }, $val;
            } else {
                $param->{$pkey} = $val;
            }
        }
    }

    $ENV{JSON_PRETTY} = defined $req->param('pretty') ? 1 : 0;

    return $param;
}

sub parse_json_request {
    my $c = shift;

    my $req = $c->req;

    my $content = $req->content || '{}';
    my $param = try {
        decode_json($content);
    } catch {
        warnf("%s: %s", $_, $content);
        return;
    };

    return $param || ();
}

sub show_internal_server_error {
    my($c, $message, $errors) = @_;
    return $c->show_error(500, $message, $errors);
}

sub show_bad_request {
    my($c, $message, $errors) = @_;
    return $c->show_error(400, $message, $errors);
}

sub show_missing_mandatory_parameter {
    my($c, undef, $errors) = @_;
    return $c->show_error(400, 'missing mandatory parameter', $errors);
}

sub show_not_found {
    my($c, undef, $errors) = @_;
    return $c->show_error(404, 'not found', $errors);
}

sub show_error {
    my($c, $code, $message, $errors) = @_;
    if ($message eq 'validation failed') {
        warnf '%s %s', $message, ddf($errors);
    } else {
        critf '%s %s', $message, ddf($errors);
    }
    my $res = $c->render_json({message => $message, errors => $errors // []});
    $res->code($code // 500);
    return $res;
}

1;
...

    $self->write_file('lib/<<PATH>>/API/CLI/Release.pm', <<'...');
package <% $module %>::CLI::Release;

use strict;
use warnings;
use 5.010_000;
use utf8;

use YAML;
use Path::Class;

use <% $module %>;
use <% $module %>::Util;

sub run {
    # かなり雑だよ！

    if (git_modified()) {
        warn "[ERROR] git commit before release\n";
        return;
    }

    my $old_version = $<% $module %>::VERSION->normal;
    my $new_version = version->parse($<% $module %>::VERSION->numify + 0.000001)->normal;
    printf "%s -> %s\n", $old_version, $new_version;

    # カレントディレクトリに依存してるので雑
    open my $rfh, '<', 'lib/<% $path %>.pm' or die $!;
    my @contents = <$rfh>;
    close $rfh;

    open my $wfh, '>', 'lib/<% $path %>.pm' or die $!;
    for (@contents) {
        s/declare\('$old_version'\)/declare('$new_version')/;
        print {$wfh} $_;
    }
    close $wfh;

    system(qq{git add -A . && git commit -m "$new_version" && git tag -m "" -a "$new_version"});
    print "TODO\n  git push; git push --tags\n";
}

sub git_modified {
    my $out = qx{git status --porcelain | grep -v ' CHANGELOG.md\$'};
    return $out ? 1 : ();
}

1;

__END__

=encoding utf8

=head1 NAME

B<<% $module %>::CLI::Release>

=head1 DESCRIPTION

Mainly used by C<daiku release>.

=cut
...

    $self->write_file('lib/<<PATH>>/ModelResponse.pm', <<'...');
package <% $module %>::ModelResponse;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Carp;
use Data::Validator;
use Data::Dumper;

use Class::Accessor::Lite (
    new => 0,
    ro  => [qw(errors)],
    rw  => [qw(content)],
);

sub new {
    my($class, %args) = @_;

    my $self    =  bless {
        %args,
        content => undef,
        errors  => [],
    }, $class;

    return $self;
}

sub has_errors {
    my $self = shift;
    return scalar(@{$self->errors}) == 0 ? 0 : 1;
}

sub add_validator_errors {
    my($self, $errors) = @_;

    state $code_by_type = {
        InvalidValue       => 'invalid',
        ExclusiveParameter => 'invalid',
        MissingParameter   => 'missing_field',
        UnknownParameter   => 'invalid',
    };

    for my $e (@$errors) {
        $self->add_error({
            field   => $e->{name},
            code    => ($code_by_type->{ $e->{type} } // 'invalid'),
            message => $e->{message},
        });
    }
}

sub add_error {
    my($self, $error) = @_;

    my $rule    =  Data::Validator->new(
        field   => { isa => 'Str' },
        code    => { isa => 'Str' },
        message => { isa => 'Str', optional => 1 },
    )->with('NoThrow');

    $error = $rule->validate(%$error);

    if ($rule->has_errors) {
        warn join("\n", map {$_->{message}} @{$rule->clear_errors});
        push @{ $self->{errors} }, {
            field => 'unknown',
            code  => 'unknown',
        };
    } else {
        push @{ $self->{errors} }, $error;
    }
}

sub as_string {
    my($self) = @_;

    local $Data::Dumper::Indent    = 1;
    local $Data::Dumper::Deepcopy  = 1;
    local $Data::Dumper::Sortkeys  = 1;
    local $Data::Dumper::Terse     = 1;
    local $Data::Dumper::Useqq     = 1;
    local $Data::Dumper::Quotekeys = 0;
    my $d =  Dumper($_[0]);
    $d    =~ s/\\x\{([0-9a-z]+)\}/chr(hex($1))/ge;
    return $d;
}

1;

__END__

=encoding utf8

=head1 NAME

B<<% $module %>::ModelResponse> - ...

=head1 SYNOPSIS

    use <% $module %>::ModelResponse;

=head1 DESCRIPTION

モデルのレスポンスクラス。

全てのモデルの全ての返り値に使うわけじゃなくて、パラメータのバリデーションや実行結果が失敗する可能性があるものにのみ使う。

具体的には、リソース（Hostとか）のCRUD（insertとか）。

なので、例えばTagモデルのidやnameメソッドの返り値には使わない。

別な言い方をすると、コントローラがモデルのエラーの詳細を知りたい局面では ModelResponse を返るが、モデルのユーティリティメソッドには使わない。

=cut
...

    $self->write_file('lib/<<PATH>>/ModelTypeConstraints.pm', <<'...');
package <% $module %>::ModelTypeConstraints;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Mouse::Util::TypeConstraints;

subtype 'QueryConditions' => as 'ArrayRef[HashRef]';
coerce 'QueryConditions'
    => from 'HashRef'
    => via { [$_] }
    ;

subtype '<% $module %>IPAddress'
    => as 'Str'
    => where { /\A(?:(?:2(?:5[0-5]|[0-4][0-9])|1[0-9]{2}|[1-9][0-9]|[0-9])\.){3}(?:2(?:5[0-5]|[0-4][0-9])|1[0-9]{2}|[1-9][0-9]|[0-9])\z/ }
    => message { 'Not IPv4 format' }
;

subtype '<% $module %>Keep'
    => as 'Int'
    => where { $_ >= 1 }
    => message { 'Must be >= 1' }
;

subtype '<% $module %>Bwlimit'
    => as 'Str'
    => where { /\A[1-9][0-9.]*[KMGkmg]?\z/ }
    => message { 'Must be N[KMG]' }
;

no Mouse::Util::TypeConstraints;

1;

__END__
...

    $self->write_file('lib/<<PATH>>/Plugin/DataValidator.pm', <<'...');
use strict;
use warnings;

package Data::Validator::Amon2;
use Mouse;
use Scalar::Util qw/blessed/;
extends 'Data::Validator';

has filter_map => (
    is  => 'ro',
    isa => 'HashRef',
);

no Mouse;

sub BUILDARGS {
    my ($class, @mapping) = @_;
    my $args = {};
    my %filter_map;
    my @mapping_4_super;
    while ( my ($name, $rule) = splice @mapping, 0, 2 ) {
        if ( ref($rule) eq 'HASH'  &&  ref($rule->{filter}) eq 'CODE' ) {
            $filter_map{$name} = $rule->{filter};
            delete $rule->{filter};
        }
        push @mapping_4_super, $name, $rule;
    }
    $args = $class->SUPER::BUILDARGS(@mapping_4_super);
    $args->{filter_map} = \%filter_map;
    return $args;
}

### override
sub validate {
    my ($self, @args) = @_;
    if ( blessed($args[0])  &&  $args[0]->isa('Plack::Request') ) {
        $args[0] = {
            %{ $args[0]->parameters->mixed || {} },
            %{ $args[0]->uploads->mixed || {} },
        };
    }
    my $args = $self->initialize(@args);  # isa Hashref
    my $fm = $self->filter_map;
    for my $k ( keys %$args ) {
        my $f = $fm->{$k};
        next  unless $f && ref($f) eq 'CODE';
        $args->{$k} = $f->($args->{$k});
    }
    return $self->SUPER::validate($args);
}

1;

package <% $module %>::Plugin::DataValidator;

our $VERSION = '0.06';

sub init {
    my ($class, $context_class, $config) = @_;
    no strict 'refs';
    *{"$context_class\::validator"}     = \&_validator;
    *{"$context_class\::new_validator"} = \&_validator;
}

sub _validator {
    my ($self, @args) = @_;
    return Data::Validator::Amon2->new(@args);
}

1;
__END__

=head1 NAME

Amon2::Plugin::DataValidator -

=head1 SYNOPSIS

  package MyApp;
  use parent 'Amon2';
  __PACKAGE__->load_plugin('DataValidator');


  package anywhere;

  # $c is a context object of MyApp(Amon2)
  my $validator = $c->new_validator(
      foo => { isa => 'Str' },
      bar => { isa => 'Num' },
      baz => { isa => 'Str', filter => { uc $_[0] } },
  );

=head1 DESCRIPTION

Amon2::Plugin::DataValidator is

=head1 AUTHOR

issm E<lt>issmxx@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
...

    $self->write_file('lib/<<PATH>>/Plugin/Model.pm', <<'...');
package <% $module %>::Plugin::Model;
use strict;
use warnings;
use Try::Tiny;
use Class::Load qw/load_class/;

our $VERSION = '0.05';

sub init {
    my ($class, $context_class, $config) = @_;

    no strict 'refs';
    my $f = _generate_func( %{ $config || +{} } );
    *{"$context_class\::model"} = $f;
}

sub _generate_func {
    my (%config) = @_;

    return sub {
        my ($self, @args) = @_;
        die 'Model name is not specified.'  unless ( grep ref($_) eq '', @args );

        my $class_prefix = ref($self);
        $class_prefix =~ s/::\w+$//;
        $class_prefix .= '::Model';

        my @models;
        while ( my $arg = shift @args ) {
            next if ref($arg) ne '';
            my ($model, $params);

            # ->model( $name => \%params )
            if ( @args > 0  &&  ref($args[0]) eq 'HASH' ) { $params = shift @args }
            $params ||= +{};
            $params->{name} = $arg  if $config{store_name};

            try {
                my $model_class = __camelize($arg);
                unless ( $model_class =~ s/^\+// || $model_class =~ /^$class_prefix/ ) {
                    $model_class = "$class_prefix\::$model_class";
                }
                load_class($model_class);
                $model = $model_class->new(
                    c => $self,
                    %$params,
                );
            } catch {
                my $msg = shift;
                die $msg;
            };

            if ( $model->can('init') ) {
                $model->init( %$params );
            }

            push @models, $model;
        }

        return wantarray ? @models : $models[0];
    };
}

sub __camelize {
    my $t = shift;
    $t =~ s/(?:^|_)(.)/uc($1)/ge;
    $t =~ s/:([^:])/':'.uc($1)/ge;
    $t =~ s/^(\+.)/uc($1)/e;
    return $t;
}

1;
__END__

=head1 NAME

Amon2::Plugin::Model - model-class loader plugin for Amon2

=head1 SYNOPSIS

  # your Amon2 application
  package YourApp;
  use parent 'Amon2';
  __PACKAGE__->load_plugin('Model');
  # or
  __PACKAGE__->load_plugin('Model' => $plugin_conf);
  ...

  # your model class
  package YourApp::Model::Foo;

  sub new {
      # context object is passed as parameter "c"
      my ($class, %params) = @_;
      return bless \%params, $class;
  }

  sub c { shift->{c} }

  sub hello {
      return 'hello';
  }

  sub search {
      my $self = shift;
      my $dbh = $self->c->dbh;
      my $sth = $dbh->prepare_cached(...);
      $sth->execute(...);
      ...
  }

  # in your code
  my $c = YourApp->bootstrap();
  my $model = $c->model('Foo' => { foo => 1 });
  print $model->{foo};    # 1
  print $model->hello();  # 'hello'
  $model->search();

=head1 DESCRIPTION

Amon2::Plugin::Model is model-class loader plugin for Amon2.

=head1 PLUGIN CONFIG

=over4

=item store_name : Bool

  # your Amon2 application
  package YourApp;
  ...
  __PACKAGE__->load_plugin('Model' => {store_name => 1});

  # your model
  package YourApp::Model::Foo;
  sub new {
    my ($class, %args) = @_;
    bless \%args, $class;
  }

  # in your code
  print $c->model('Foo')->{name};                   # 'Foo'
  print $c->model('+YourApp::Model::Foo')->{name};  # '+YourApp::Model::Foo'

=back

=head1 AUTHOR

issm E<lt>issmxx@gmail.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
...

    $self->write_file('lib/<<PATH>>/Plugin/Web/JSON.pm', <<'...');
package <% $module %>::Plugin::Web::JSON;

use strict;
use warnings;
use 5.010_000;
use JSON 2 qw/encode_json/;
use Amon2::Util ();

my $_JSON = JSON->new()->ascii(1);

my %_ESCAPE = (
    '+' => '\\u002b', # do not eval as UTF-7
    '<' => '\\u003c', # do not eval as HTML
    '>' => '\\u003e', # ditto.
);

sub init {
    my ($class, $c, $conf) = @_;
    unless ($c->can('render_json')) {
        Amon2::Util::add_method($c, 'render_json', sub {
            my ($c, $stuff, $code) = @_;

            $code //= 200;

            # for IE7 JSON venularity.
            # see http://www.atmarkit.co.jp/fcoding/articles/webapp/05/webapp05a.html
            my $output = $_JSON->canonical( ( $conf->{canonical} or $ENV{JSON_PRETTY} ) ? 1 : 0 )->pretty( $ENV{JSON_PRETTY} ? 1 : 0 )->encode($stuff);
            $output =~ s!([+<>])!$_ESCAPE{$1}!g;

            my $user_agent = $c->req->user_agent || '';

            # defense from JSON hijacking
            if ((!$c->request->header('X-Requested-With')) && $user_agent =~ /android/i && defined $c->req->header('Cookie') && ($c->req->method||'GET') eq 'GET') {
                my $res = $c->create_response(403);
                $res->content_type('text/html; charset=utf-8');
                $res->content("Your request may be JSON hijacking.\nIf you are not an attacker, please add 'X-Requested-With' header to each request.");
                $res->content_length(length $res->content);
                return $res;
            }

            my $res = $c->create_response($code);

            my $encoding = $c->encoding();
            $encoding = lc($encoding->mime_name) if ref $encoding;
            $res->content_type("application/json; charset=$encoding");
            $res->header( 'X-Content-Type-Options' => 'nosniff' ); # defense from XSS
            $res->content_length(length($output));
            $res->body($output);

            if (defined (my $status_code_field =  $conf->{status_code_field})) {
                $res->header( 'X-API-Status' => $stuff->{$status_code_field} ) if exists $stuff->{$status_code_field};
            }

            return $res;
        });
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Amon2::Plugin::Web::JSON - JSON plugin

=head1 SYNOPSIS

    use Amon2::Lite;

    __PACKAGE__->load_plugins(qw/Web::JSON/);

    get '/' => sub {
        my $c = shift;
        return $c->render_json(+{foo => 'bar'});
    };

    __PACKAGE__->to_app();

=head1 DESCRIPTION

This is a JSON plugin.

=head1 METHODS

=over 4

=item C<< $c->render_json(\%dat); >>

Generate JSON data from C<< \%dat >> and returns instance of L<Plack::Response>.

=back

=head1 PARAMETERS

=over 4

=item status_code_field

It specify the field name of JSON to be embedded in the 'X-API-Status' header.
Default is C<< undef >>. If you set the C<< undef >> to disable this 'X-API-Status' header.

    __PACKAGE__->load_plugins(
        'Web::JSON' => { status_code_field => 'status' }
    );
    ...
    $c->render_json({ status => 200, message => 'ok' })
    # send response header 'X-API-Status: 200'

In general JSON API error code embed in a JSON by JSON API Response body.
But can not be logging the error code of JSON for the access log of a general Web Servers.
You can possible by using the 'X-API-Status' header.

=item canonical

If canonical parameter is true, then this plugin will output JSON objects by sorting their keys.
This is adding a comparatively high overhead.

    __PACKAGE__->load_plugins(
        'Web::JSON' => { canonical => 1 }
    );
    ...
    $c->render_json({ b => 1, c => 1, a => 1 });
    # json response is '{ "a" : 1, "b" : 1, "c" : 1 }'

=back

=head1 FAQ

=over 4

=item How can I use JSONP?

You can use JSONP by using L<Plack::Middleware::JSONP>.

=back

=head1 JSON and security

=over 4

=item Browse the JSON files directly.

This module escapes '<', '>', and '+' characters by "\uXXXX" form. Browser don't detects the JSON as HTML.

And also this module outputs C<< X-Content-Type-Options: nosniff >> header for IEs.

It's good enough, I hope.

=item JSON Hijacking

Latest browsers doesn't have a JSON hijacking issue(I hope). __defineSetter__ or UTF-7 attack was resolved by browsers.

But Firefox<=3.0.x and Android phones have issue on Array constructor, see L<http://d.hatena.ne.jp/ockeghem/20110907/p1>.

Firefox<=3.0.x was outdated. Web application developers doesn't need to add work-around for it, see L<http://en.wikipedia.org/wiki/Firefox#Version_release_table>.

L<Amon2::Plugin::Web::JSON> have a JSON hijacking detection feature. Amon2::Plugin::Web::JSON returns "403 Forbidden" response if following pattern request.

=over 4

=item The request have 'Cookie' header.

=item The request doesn't have 'X-Requested-With' header.

=item The request contains /android/i string in 'User-Agent' header.

=item Request method is 'GET'

=back

=back

See also the L<hasegawayosuke's article(Japanese)|http://www.atmarkit.co.jp/fcoding/articles/webapp/05/webapp05a.html>.

=head1 FAQ

=over 4

=item HOW DO YOU CHANGE THE HTTP STATUS CODE FOR JSON?

render_json method returns instance of Plack::Response. You can modify the response object.

Here is a example code:

    get '/' => sub {
        my $c = shift;
        if (-f '/tmp/maintenance') {
            my $res = $c->render_json({err => 'Under maintenance'});
            $res->status(503);
            return $res;
        }
        return $c->render_json({err => undef});
    };

=back

=head1 THANKS TO

hasegawayosuke

...

    $self->write_file('lib/<<PATH>>/Plugin/Web/Session.pm', <<'...');
package <% $module %>::Plugin::Web::Session;
use strict;
use warnings;
use utf8;

use Amon2::Util;
use HTTP::Session2::ClientStore2;
use Crypt::CBC;

sub init {
    my ($class, $c) = @_;

    # Validate XSRF Token.
    unless ($ENV{SKIP_XSRF_VALIDATION}) {
        $c->add_trigger(
            BEFORE_DISPATCH => sub {
                my ( $c ) = @_;
                if ($c->req->method ne 'GET' && $c->req->method ne 'HEAD') {
                    my $token = $c->req->header('X-XSRF-TOKEN') || $c->req->param('XSRF-TOKEN');
                    unless ($c->session->validate_xsrf_token($token)) {
                        return $c->create_simple_status_page(
                            403, 'XSRF detected.'
                        );
                    }
                }
                return;
            },
        );
    }

    Amon2::Util::add_method($c, 'session', \&_session);

    # Inject cookie header after dispatching.
    $c->add_trigger(
        AFTER_DISPATCH => sub {
            my ( $c, $res ) = @_;
            if ($c->{session} && $res->can('cookies')) {
                $c->{session}->finalize_plack_response($res);
            }
            return;
        },
    );
}

# $c->session() accessor.
my $cipher = Crypt::CBC->new({
    key => 'wrA8utcdx3qLt0lIg2zOVpsMRTSba2mI',
    cipher => 'Rijndael',
});
sub _session {
    my $self = shift;

    if (!exists $self->{session}) {
        $self->{session} = HTTP::Session2::ClientStore2->new(
            env => $self->req->env,
            secret => 'HIl_xrtUzVz_jVWsLWXxZd3fcDtR-cXY',
            cipher => $cipher,
        );
    }
    return $self->{session};
}

1;
__END__

=head1 DESCRIPTION

This module manages session for <% $module %>.

...

    $self->write_file('lib/<<PATH>>/Util.pm', <<'...');
package <% $module %>::Util;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Carp;

use parent qw(Exporter);
our @EXPORT = qw(
                    p
                    to_array
                    mask_credential
            );

use Data::Dumper;

sub p($) { ## no critic
    local $Data::Dumper::Indent    = 1;
    local $Data::Dumper::Deepcopy  = 1;
    local $Data::Dumper::Sortkeys  = 1;
    local $Data::Dumper::Terse     = 1;
    local $Data::Dumper::Useqq     = 1;
    local $Data::Dumper::Quotekeys = 0;
    my $d =  Dumper($_[0]);
    $d    =~ s/\\x\{([0-9a-z]+)\}/chr(hex($1))/ge;
    print STDERR $d;
}

sub to_array {
    my $v = shift;
    my $type = ref $v;
    if (!$type) {
        return ($v);
    } elsif ($type eq 'ARRAY') {
        return @{$v};
    } else {
        croak "cannot convert to array: type=$type";
    }
}

sub mask_credential {
    my($str) = @_;

    $str =~ s/password":".+?"/password":"XXX"/g; # JSON

    return $str;
}

1;
...

    $self->write_file('lib/<<PATH>>/API/Dispatcher.pm', <<'...');
package <% $module %>::API::Dispatcher;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Carp;
use Log::Minimal;
use JSON 2 qw(encode_json decode_json);
use Try::Tiny;
use HTTP::Status;

use Amon2::Web::Dispatcher::RouterBoom;

use <% $module %>;
use <% $module %>::Util;

any '/' => sub {
    my ($c) = @_;
    my $counter = $c->session->get('counter') || 0;
    $counter++;
    $c->session->set('counter' => $counter);
    return $c->render('index.tx', {
        counter => $counter,
    });
};

{
    no warnings 'redefine';
    package
        HTTP::Status;
    *status_message_orig = \&status_message;
    *status_message = sub ($) {
        +{
            599 => 'Under Maintenance',
        }->{$_[0]} || status_message_orig($_[0]);
    }
}

get '/_chk' => sub {
    my $c = shift;

    my($status, $body);

    if ($c->config->{maintenance_file} && -e $c->config->{maintenance_file}) {
        $status = 599;
        $body   = 'MAINTAIN';
    } else {
        $status = 200;
        $body   = 'OK';
    }

    return $c->create_response(
        $status,
        [
            'Content-Type'   => 'text/plain',
            'Content-Length' => length($body)
        ],
        $body,
    );
};

get '/status' => sub {
    my $c = shift;

    my $body = "";

    $body .= sprintf "<% $module %>-API/%s\n", $<% $module %>::VERSION;

    return $c->create_response(
        200,
        [
            'Content-Type'   => 'text/plain',
            'Content-Length' => length($body)
        ],
        $body,
    );
};

############################################################################

# capability
get '/v1/capability' => sub {
    my($c, $args) = @_;

    # <% $module %>::APIのBEFORE_DISPATCHでやった方がいいかなぁ
    # でも将来的に v1 は 1.0 以上、v2 は 2.0 以上、とか API version に
    # よって変えたくなるかもだしここでやる。

    my $require_version = '1.0';
    my $content = {
        message => 'OK',
    };

    my $ua = $c->req->user_agent;
    if ($ua =~ m{\A<% $module %>/([0-9]+\.[0-9]+)\z}) {
        my $client_version = $1;
        debugf 'its <% $module %> client v%s', $client_version;
        if ($client_version < $require_version) {
            $content->{message} = sprintf 'client version must be %s or later', $require_version;
        }
    } else {
        $content->{message} = 'not looks like 2ndbackup client program';
    }

    return $c->render_json($content);
};

get '/v1/user/:user_name' => sub {
    my($c, $args) = @_;

    my $param = $c->parse_json_qs_request
        or return $c->show_bad_request(
            'failed to parse JSON' => [
                {
                    code => 'invalid',
                },
            ]);

    my $mres = $c->model('User')->info({
        %$param,
    });

    return $mres->has_errors
        ? $c->show_bad_request('validation failed', $mres->errors)
        : $c->render_json($mres->content);
};

1;
...

    $self->write_file('lib/<<PATH>>/API/View.pm', <<'...');
package <% $module %>::API::View;
use strict;
use warnings;
use utf8;
use Carp ();
use File::Spec ();

use File::ShareDir;
use Text::Xslate 1.6001;
use <% $module %>::API::ViewFunctions;

# setup view class
sub make_instance {
    my ($class, $context) = @_;
    Carp::croak("Usage: <% $module %>::API::View->make_instance(\$context_class)") if @_!=2;

    my $view_conf = $context->config->{'Text::Xslate'} || +{};
    unless (exists $view_conf->{path}) {
        my $tmpl_path = File::Spec->catdir($context->base_dir(), 'tmpl');
        if ( -d $tmpl_path ) {
            # tmpl
            $view_conf->{path} = [ $tmpl_path ];
        } else {
            my $share_tmpl_path = eval { File::Spec->catdir(File::ShareDir::dist_dir('<% $dist %>'), 'tmpl') };
            if ($share_tmpl_path) {
                # This application was installed to system.
                $view_conf->{path} = [ $share_tmpl_path ];
            } else {
                Carp::croak("Can't find template directory. tmpl Is not available.");
            }
        }
    }
    my $view = Text::Xslate->new(+{
        'syntax'   => 'Kolon',
        'module'   => [
            'Text::Xslate::Bridge::Star',
            '<% $module %>::API::ViewFunctions',
        ],
        'function' => {
        },
        ($context->debug_mode ? ( warn_handler => sub {
            Text::Xslate->print( # print method escape html automatically
                '[[', @_, ']]',
            );
        } ) : () ),
        %$view_conf
    });
    return $view;
}

1;
...

    $self->write_file('lib/<<PATH>>/API/ViewFunctions.pm', <<'...');
package <% $module %>::API::ViewFunctions;
use strict;
use warnings;
use utf8;
use parent qw(Exporter);
use Module::Functions;
use File::Spec;

our @EXPORT = get_public_functions();

sub commify {
    local $_  = shift;
    1 while s/((?:\A|[^.0-9])[-+]?\d+)(\d{3})/$1,$2/s;
    return $_;
}

sub c { <% $module %>->context() }
sub uri_with { <% $module %>->context()->req->uri_with(@_) }
sub uri_for { <% $module %>->context()->uri_for(@_) }

{
    my %static_file_cache;
    sub static_file {
        my $fname = shift;
        my $c = <% $module %>->context;
        if (not exists $static_file_cache{$fname}) {
            my $fullpath = File::Spec->catfile($c->base_dir(), $fname);
            $static_file_cache{$fname} = (stat $fullpath)[9];
        }
        return $c->uri_for(
            $fname, {
                't' => $static_file_cache{$fname} || 0
            }
        );
    }
}

1;
...

    $self->write_file('lib/<<PATH>>/Model/User.pm', <<'...');
package <% $module %>::Model::Usages;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Log::Minimal;
use Try::Tiny;

use <% $module %>::ModelResponse;
use <% $module %>::ModelTypeConstraints;
use <% $module %>::Util;

use Class::Accessor::Lite (
    new => 0,
    ro  => [qw(c)]
);

sub new {
    my($class, %args) = @_;
    return bless \%args, $class;
}

sub search {
    my($self, $param) = @_;

    my $mres = <% $module %>::ModelResponse->new;

    my $rule = $self->c->validator(
        q => { isa => 'QueryConditions' },
    )->with('NoThrow');

    $param = $rule->validate(%$param);

    if ($rule->has_errors) {
        $mres->add_validator_errors($rule->clear_errors);
        return $mres;
    }

    my $conds = $param->{q};

    my $rule_q = $self->c->validator(
        id   => { isa => 'Int|ArrayRef[Int]', optional => 1 },
        name => { isa => 'Str|ArrayRef[Str]', optional => 1 },
    )->with('NoThrow','NoRestricted');
    for my $cond (@$conds) {
        $cond = $rule_q->validate(%$cond);
        if ($rule_q->has_errors) {
            $mres->add_validator_errors($rule_q->clear_errors);
        }
    }

    if ($mres->has_errors) {
        return $mres;
    }

    my @result;
    $conds = [{}] unless @$conds; # select all data
    for my $cond (@$conds) {
        my $iter = try {
            $self->c->db->search('users', $cond);
        } catch {
            $mres->add_error({
                field   => 'users',
                code    => 'missing',
                message => 'failed to search users: '.$_,
            });
            return;
        };
        unless ($iter) {
            return $mres;
        }

        $iter->suppress_object_creation(1);
        while (my $user = $iter->next) {
            push @result, $user;
        }
    }

    $mres->content(\@result);

    return $mres;
}

sub fetch {
    my($self, $param) = @_;

    my $mres = <% $module %>::ModelResponse->new;

    my $rule = $self->c->validator(
        name => { isa => 'Str|ArrayRef[Str]' },
    )->with('NoThrow');

    $param = $rule->validate(%$param);

    if ($rule->has_errors) {
        $mres->add_validator_errors($rule->clear_errors);
        return $mres;
    }

    $mres = $self->search({ q => [{ name => $param->{name_id} }] });

    return $mres;
}

sub insert {
    my($self, $param) = @_;

    my $mres = <% $module %>::ModelResponse->new;

    my $rule = $self->c->validator(
        name => { isa => 'Str' },
    )->with('NoThrow','NoRestricted');

    $param = $rule->validate(%$param);

    if ($rule->has_errors) {
        $mres->add_validator_errors($rule->clear_errors);
        return $mres;
    }

    # idempotence
    $mres = $self->search({ q => [$param] });
    if ($mres->has_errors) {
        $mres->add_error({
            message => "failed to get user info",
            field   => 'users',
            code    => 'invalid',
        });
        return $mres;
    }
    if (scalar(@{ $mres->content }) > 0) {
        debugf("user %s already exists", $mres->content->[0]{name});
        $mres->content($mres->content->[0]);
        return $mres;
    }

    my $id = try {
        $self->c->db->fast_insert('users', $param)
    } catch {
        $mres->add_error({
            field   => 'users',
            code    => 'missing',
            message => 'failed to insert usages: '.$_,
        });
        return;
    };
    unless ($id) {
        return $mres;
    }

    $mres = $self->fetch({name => $param->{name}});
    unless ($mres->has_errors) {
        $mres->content( $mres->content->[0] );
    }

    return $mres;
}

sub delete {
    my($self, $param) = @_;

    my $mres = <% $module %>::ModelResponse->new;

    my $rule = $self->c->validator(
        usage_id => { isa => 'Int|ArrayRef[Int]' },
    )->with('NoThrow');

    $param = $rule->validate(%$param);

    if ($rule->has_errors) {
        $mres->add_validator_errors($rule->clear_errors);
        return $mres;
    }

    my $count = $self->c->db->delete('usages', $param);

    $mres->content($count);

    return $mres;
}

1;

__END__

# for Emacsen
# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# cperl-close-paren-offset: -4
# cperl-indent-parens-as-block: t
# indent-tabs-mode: nil
# coding: utf-8
# End:

# vi: set ts=4 sw=4 sts=0 et ft=perl fenc=utf-8 ff=unix :

...



    {
        my $path = $self->render_string('lib/<% $path %>/Web/Plugin/');
        system("rm -fr $path");
    }


}

1;

__END__

=encoding utf8

=head1 NAME

Amon2::Setup::Flavor::JSONAPI - Amon2 flavor for JSON API

=begin readme

=head1 INSTALLATION

To install this module, run the following commands:

    perl Build.PL
    ./Build
    ./Build test
    ./Build install

=end readme

=head1 SYNOPSIS

    amon2-setup --flavor Basic,JSONAPI MyAPI

=head1 DESCRIPTION

Amon2::Setup::Flavor::JSONAPI is Amon2 flavor for JSON API.

=head1 AUTHOR

HIROSE Masaaki E<lt>hirose31@gmail.comE<gt>

=head1 REPOSITORY

L<https://github.com/hirose31/Amon2-Setup-Flavor-JSONAPI>

    git clone https://github.com/hirose31/Amon2-Setup-Flavor-JSONAPI.git

patches and collaborators are welcome.

=head1 COPYRIGHT

Copyright HIROSE Masaaki

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# for Emacsen
# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# cperl-close-paren-offset: -4
# cperl-indent-parens-as-block: t
# indent-tabs-mode: nil
# coding: utf-8
# End:

# vi: set ts=4 sw=4 sts=0 et ft=perl fenc=utf-8 ff=unix :
