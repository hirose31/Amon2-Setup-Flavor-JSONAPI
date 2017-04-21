use strict;
use warnings;
use utf8;

package Amon2::Setup::Flavor::JSONAPI;
use parent qw(Amon2::Setup::Flavor::Basic);
our $VERSION = '1.001';

=pod

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

    amon2-setup --flavor JSONAPI MyAPI

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

sub run {
    my ($self) = @_;

    $self->SUPER::run();

    require Amon2;

    my $tmpl_val = {
    };
    # パスのテンプレでも使うので
    $self->{distlc} = lc($self->{dist});

    {
        # create_cpanfile
        my $cpanfile = Module::CPANfile->from_prereqs(
            {
                runtime => {
                    requires => {
                        'perl'              => '5.010_001',
                        'Amon2'             => $Amon2::VERSION,
                        'Text::Xslate'      => '2.0009',
                        'Starlet'           => '0.20',
                        'Module::Functions' => 2,

                        'Log::Minimal'                 => 0,
                        'Path::Class'                  => 0,
                        'Class::Accessor::Lite'        => 0,
                        'Redis'                        => 0,
                        'Redis::Key'                   => 0,
                        'Redis::Namespace'             => 0,
                        'Data::Validator'              => 0,
                        'Data::Validator::Recursive'   => 0,
                        'IPC::Cmd'                     => 0,
                        'IPC::Run'                     => 0,
                        'Sub::Retry'                   => 0,
                        'Try::Tiny'                    => 0,
                        'Parallel::Prefork'            => 0,
                        'DBI'                          => 0,
                        'DBIx::QueryLog'               => 0,
                        'DBD::mysql'                   => 0,
                        'Daiku'                        => 0,
                        'WWW::Form::UrlEncoded::XS'    => 0,
                        'Teng::Schema::Declare'        => 0,
                        'Plack::Middleware::Deflater'  => 0,
                        'Plack::Builder::Conditionals' => 0,
                    },
                },
                configure => {
                    requires => {
                        'Module::Build'    => '0.38',
                        'Module::CPANfile' => '0.9020',
                    },
                },
                test => {
                    requires => {
                        'Test::More' => '0.98',

                        'Test::mysqld'                => 0,
                        'Harriet'                     => 0,
                        'Test::Pretty'                => 0,
                        'DBIx::FixtureLoader'         => 0,
                        'App::Prove::Plugin::Harriet' => 0,
                        'FindBin'                     => 0,
                    },
                },
            }
        );
        $self->write_file('cpanfile', $cpanfile->to_string());
    }

    $self->write_file('API.md', <<'...', $tmpl_val);
# <% $dist %> API Reference

please generate by `daiku api`
...

    $self->write_file('Daikufile', <<'...', $tmpl_val);
# -*- mode: perl -*-

desc 'run test';
task test => sub {
    my ($task, @args) = @_;
    sh qw(carton exec -- prove -r t), @args;
};

desc 'run test with -v option';
task testv => sub {
    my ($task, @args) = @_;
    sh qw(carton exec -- prove -rv t), @args;
};

desc 'dump schema';
task dump_schema => sub {
    require <% $module %>::API::CLI::DumpSchema;
    <% $module %>::CLI::DumpSchema->run;
};

desc 'dump data';
task dump_data => sub {
    require <% $module %>::API::CLI::DumpData;
    <% $module %>::CLI::DumpData->run;
};

desc 'release next version';
task release => sub {
    require <% $module %>::API::CLI::Release;
    <% $module %>::CLI::Release->run;
};

desc 'generate API.md';
task 'api' => 'API.md';
file 'API.md' => 'schema/schema.json' => sub {
    my $file = shift;
    sh sprintf('prmd doc --settings schema/config.yml -o %s %s', $file->dst, $file->deps->[0]);
};

desc 'combine JSON schema';
task 'combine' => 'schema/schema.json';
file 'schema/schema.json' => 'schema/meta.yml' => sub {
    my $file = shift;
    sh sprintf('prmd combine --meta schema/meta.yml -o %s schema/schemata/', $file->dst);
};
...

    $self->write_file('README.md', <<'...', $tmpl_val);
# <% $dist %> API

<!-- fixme M-x markdown-toc-generate-toc -->

## API Document

- [API Reference](API.md)

## Installation

```
cpanm Carton
cd <% $dist %>/
carton install
carton exec -- plackup -I lib -R lib --access-log /dev/null -p 5000 ./script/<% $distlc %>-api-server
```

## Operation

### APIドキュメントを更新する

```
vi schema/schemata/xxx.yml

daiku api
```

### モジュール追加したとき

```
vi cpanfile
carton install
```

### DBのスキーマを変更したい

```
carton exec -- harriet t/harriet &

export TEST_MYSQL='DBI:mysql:...'
mysql -uroot -S ... -D test
# スキーマを変更する

daiku dump_schema
```

### テストを実行する

```
daiku test
もしくは
daiku testv
```

### リリース

```
daiku release
git push
git push --tags
```

### デプロイ

`fixme` のホストそれぞれについて実行する。

```
### fixme
cd ~fixme/repos/<% $dist %>/
git pull
sudo svc -h /service/<% $distlc %>-api
# バージョンアップした場合はこれで確認できる。
# プロセスが生まれ変わるまで数秒かかるので何度か実行して確認する。
curl http://127.0.0.1:5010/status
```

## 環境変数

### `PLACK_ENV`

ロードする設定ファイルの決定に使われる。 (`config/$PLACK_ENV.pl`)

本番、開発環境では `INFRA_ENV` と同じ値がセットされる。[service/<% $distlc %>-api/run](service/<% $distlc %>-api/run)

開発時は `development` か、自分の好きなのをセットすればよい。

省略時は `development` になる。

`test` はテストに使っているので使わないでください。

### `RUN_MODE`

動作モードの決定に使われる。

`development` とセットされた場合、以下のようになる。

- `DBIx::QueryLog` を有効にする
- Log::Minimalのログレベルを debug にする (`$ENV{LM_DEBUG} = 1;`)

開発時は `development` にするとよい。

## DB

### 初期データ

`prove`や`harriet t/harriet`を実行した際に`t/harriet/mysqld.pl`が実行される。

`t/harriet/mysqld.pl`は、ファイル`tmp/test_mysql_copy_data_from/initialized`が存在しない場合、`tmp/test_mysql_copy_data_from/` の下に初期データを用意して、ファイル`tmp/test_mysql_copy_data_from/initialized`をtouchする。

ファイル`tmp/test_mysql_copy_data_from/initialized` が存在する場合は、それをコピーしてコピーしたものを参照するmysqldを起動する。つまり、コピー元の`tmp/test_mysql_copy_data_from/`は更新されずきれいなまま。

### 開発中で、テスト用のmysqldを上げっぱなしにしたいとき

```
carton exec -- harriet t/harriet
```

`export TEST_MYSQL='DBI:mysql:...'` と表示されるので、テストを実行したいターミナルでコピペする。


...

    $self->write_file('.gitignore', <<'...', $tmpl_val);
Makefile
/inc/
MANIFEST
*.bak
*.old
nytprof.out
nytprof/
*.db
/blib/
pm_to_blib
META.json
META.yml
MYMETA.json
MYMETA.yml
/Build
/_build/
/local/
/.carton/

/var/
/data/
/tmp/

/service/*/supervise
/service/*/log/supervise
/service/*/log/main/
/service/*/env/*
!/service/*/env/.gitkeep
/service/*/*/env/*
!/service/*/*/env/.gitkeep
...

    $self->write_file('.proverc', <<'...', $tmpl_val);
--exec "env PLACK_ENV=test perl -Ilib -MTest::Pretty -MTest::Name::FromLine"
-PPretty
-PHarriet=./t/harriet
--timer
--merge
--trap
--color
--failures
-w
...

    $self->write_file('config/development.pl', <<'...', $tmpl_val);
use Path::Class;

my $root_dir = file(__FILE__)->parent->parent->resolve;
my $data_dir = $root_dir->subdir('var');

my $dbuser     = q{root};
my $dbpass     = q{};
my $dbhost     = q{127.0.0.1};
my $dbdatabase = q{test};

+{
    'data_dir' => $data_dir->stringify,
    'maintenance_file' => '/tmp/maintenance',
    'allow_from' => sub { 1 },
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

    $self->write_file('config/test.pl', <<'...', $tmpl_val);
use Path::Class;

my $data_dir = Path::Class::tempdir(CLEANUP => 1);

my $dbuser     = q{root};
my $dbpass     = q{};

+{
    'data_dir' => $data_dir->stringify,
    'maintenance_file' => '/tmp/maintenance',
    'allow_from' => sub { 1 },
    'DBI' => [
        undef,
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

use <% $module %>::DB::Schema;
use <% $module %>::DB;
use <% $module %>::Redis;
use <% $module %>::Util;

use parent qw/Amon2/;
# Enable project local mode.
__PACKAGE__->make_local_context();

__PACKAGE__->load_plugins(
    '+<% $module %>::Plugin::Model',
    '+<% $module %>::Plugin::DataValidator',
);

my $schema = <% $module %>::DB::Schema->instance;

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

    if ($ENV{TEST_MYSQL}) {
        # connect to Test::mysqld instance
        $config->{DBI}[0] = $ENV{TEST_MYSQL};
    }
    infof 'dsn: %s', $config->{DBI}[0] // '';

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

sub db {
    my $c = shift;
    if (!exists $c->{db}) {
        my $conf = $c->config->{DBI}
            or die "Missing configuration about DBI";
        $c->{db} = <% $module %>::DB->new(
            schema       => $schema,
            connect_info => [@$conf],
            # I suggest to enable following lines if you are using mysql.
            # on_connect_do => [
            #     'SET SESSION sql_mode=STRICT_TRANS_TABLES;',
            # ],
        );
    }
    $c->{db};
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
        debugf 'ua: %s', $ua // '';

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

sub show_mres_error {
    my($c, $mres) = @_;

    my $message = $mres->content // 'internal server error';

    if ($message eq 'validation failed') {
        return $c->show_bad_request($message, $mres->errors);
    } else {
        return $c->show_internal_server_error($message, $mres->errors);
    }
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

    $code //= 500;

    if ($code =~ /^5/) {
        critf '%s %s', $message, ddf($errors);
    } else {
        warnf '%s %s', $message, ddf($errors);
    }

    my $res = $c->render_json({message => $message, errors => $errors // []});
    $res->code($code);
    return $res;
}

1;
...

    $self->write_file('lib/<<PATH>>/API/CLI/DumpData.pm', <<'...', $tmpl_val);
package <% $module %>::CLI::DumpData;

use strict;
use warnings;
use 5.010_000;
use utf8;

use YAML;
use Path::Class;

use <% $module %>;
use <% $module %>::Util;

my @tables = qw(users);
if ($ENV{DUMP_TABLE}) {
    @tables = split /\s+/, $ENV{DUMP_TABLE};
}

sub run {
    my $c = <% $module %>->bootstrap();
    my $dbh = $c->db->dbh;

    for my $table (@tables) {
        print "$table\n";
        my $res = $dbh->selectall_arrayref("select * from $table", +{ Slice => +{} });
        dir('data')->file($table.'.yaml')->spew(iomode => '>:encoding(UTF-8)', YAML::Dump($res));
    }
}

1;

__END__

=encoding utf8

=head1 NAME

B<<% $module %>::CLI::DumpData>

=head1 DESCRIPTION

Mainly used by C<daiku dump_data>.

=cut
...

    $self->write_file('lib/<<PATH>>/API/CLI/DumpSchema.pm', <<'...', $tmpl_val);
package <% $module %>::CLI::DumpSchema;

use strict;
use warnings;
use 5.010_000;
use utf8;

use DBI;
use Path::Class;
use Teng::Schema::Dumper;
use Test::mysqld;

my %json_bool = (
    inflate => <<'EOSUB',
sub {
    my $v = shift;
    return $v ? \1 : \0;
};
EOSUB
    deflate => <<'EOSUB',
sub {
    my $v = shift;
    return $v ? 1 : 0;
};
EOSUB
);

sub run {
    my $mysqld = Test::mysqld->new(my_cnf => { 'skip-networking' => '' })
        or die $Test::mysqld::errstr;
    my $dbh = DBI->connect($mysqld->dsn);

    my $file_name = 'sql/ddl.sql';
    my $source    = file($file_name)->slurp;

    for my $stmt (split /;/, $source) {
        next unless $stmt =~ /\S/;
        $dbh->do($stmt) or die $dbh->errstr;
    }

    my $schema_class = 'lib/<% $path %>/DB/Schema.pm';
    my @modules = qw(
                        Carp
                );
    my $use_modules = '';
    $use_modules = 'use '.join(";\nuse ", @modules).";\n" if @modules;
    open my $fh, '>', $schema_class or die "$schema_class \: $!";
    my $content = Teng::Schema::Dumper->dump(
        dbh => $dbh,
        namespace      => '<% $module %>::DB',
        base_row_class => '<% $module %>::DB::Row',
        inflate        => {
            assets => q|
    for my $c (qw(evaluation_flg)) {
        inflate $c => |.$json_bool{inflate}.q|
        deflate $c => |.$json_bool{deflate}.q|
    }
|,
            hosts => q|
    inflate 'exception' => |.$json_bool{inflate}.q|
    deflate 'exception' => sub {
        my $v = shift;
        return $v ? 'exception' : undef;
    };

    for my $c (qw(monitor_ignore_flg dr_switch_daemon_flg)) {
        inflate $c => |.$json_bool{inflate}.q|
        deflate $c => |.$json_bool{deflate}.q|
    }
|,
        },
    );
    $content =~ s{(use warnings;)}{$1\n$use_modules};
    print $fh $content;
    close $fh;
}

1;

__END__

=encoding utf8

=head1 NAME

B<<% $module %>::CLI::DumpSchema>

=head1 DESCRIPTION

Mainly used by C<daiku dump_schema>.

=cut
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

    $self->write_file('lib/<<PATH>>/API/Dispatcher.pm', <<'...', $tmpl_val);
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
        $content->{message} = 'not looks like <% $dist %> client program';
    }

    return $c->render_json($content);
};

### users ##################################################################
get '/v1/search/users' => sub {
    my($c, $args) = @_;

    my $param = $c->parse_json_qs_request
        or return $c->show_bad_request(
            'failed to parse JSON' => [{code => 'invalid'}],
        );

    my $mres = $c->model('User')->search($param);

    return $mres->has_errors
        ? $c->show_mres_error($mres)
        : $c->render_json($mres->content);
};

get '/v1/users/:user_name' => sub {
    my($c, $args) = @_;

    my $param = $c->parse_json_qs_request
        or return $c->show_bad_request(
            'failed to parse JSON' => [{code => 'invalid'}],
        );

    my $mres = $c->model('User')->fetch({
        name => $args->{user_name},
    });

    return $mres->has_errors
        ? $c->show_mres_error($mres)
        : scalar(@{ $mres->content }) != 1
          ? $c->show_internal_server_error('got several results')
          : $c->render_json($mres->content->[0]);
};

post '/v1/users' => sub {
    my($c, $args) = @_;

    my $param = $c->parse_json_request
        or return $c->show_bad_request(
            'failed to parse JSON' => [{code => 'invalid'}],
        );

    my $mres = $c->model('User')->insert($param);

    return $mres->has_errors
        ? $c->show_mres_error($mres)
        : $c->render_json($mres->content, 201);
};

put '/v1/users/:user_name' => sub {
    my($c, $args) = @_;

    my $param = $c->parse_json_request
        or return $c->show_bad_request(
            'failed to parse JSON' => [{code => 'invalid'}],
        );

    my $mres = $c->model('User')->update({
        %$param,
        key => $args->{user_name},
    });

    return $mres->has_errors
        ? $c->show_mres_error($mres)
        : $c->render_json($mres->content);
};

delete_ '/v1/users/:user_name' => sub {
    my($c, $args) = @_;

    my $mres = $c->model('User')->delete({ name => $args->{user_name} });

    return $mres->has_errors
        ? $c->show_mres_error($mres)
        : $mres->content == 0
          ? $c->render_json({}, 404)
          : $c->render_json({}, 204);
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

    $self->write_file('lib/<<PATH>>/DB/Schema.pm', <<'...', $tmpl_val);
package <% $module %>::DB::Schema;
use strict;
use warnings;
use Carp;

use Teng::Schema::Declare;
base_row_class '<% $module %>::DB::Row';
table {
    name 'users';
    pk 'id';
    columns (
        {name => 'id', type => 4},
        {name => 'name', type => 12},
    );
};

1;
...

    $self->write_file('lib/<<PATH>>/Model/User.pm', <<'...', $tmpl_val);
package <% $module %>::Model::User;

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

    my @result;
    $conds = [{}] unless @$conds; # select all data
    for my $cond (@$conds) {
        my $iter = try {
            $self->c->db->search('users', $cond);
        } catch {
            $mres->content('failed to search users');
            $mres->add_error({
                field   => 'users',
                code    => 'fatail',
                message => $_,
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
        id   => { isa => 'Int', xor => [qw(name)] },
        name => { isa => 'Str', xor => [qw(id)] },
    )->with('NoThrow');

    $param = $rule->validate(%$param);

    if ($rule->has_errors) {
        $mres->add_validator_errors($rule->clear_errors);
        return $mres;
    }

    if (exists $param->{id}) {
        $mres = $self->search({ q => [{ id => $param->{id} }] });
    } else {
        $mres = $self->search({ q => [{ name => $param->{name} }] });
    }

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
            code    => 'fatal',
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
        $mres->content('failed to insert user');
        $mres->add_error({
            field   => 'users',
            code    => 'fatal',
            message => $_,
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

sub update {
    my($self, $param) = @_;

    my $mres = <% $module %>::ModelResponse->new;
    my $rule = $self->c->validator(
        key  => { isa => 'Str' },

        name => { isa => 'Str', optional =>1 },
    )->with('NoThrow');

    $param = $rule->validate(%$param);

    if ($rule->has_errors) {
        $mres->add_validator_errors($rule->clear_errors);
        return $mres;
    }

    my %newval = %{ $param };
    my $key_val = delete $newval{key};

    ### begin transaction
    my $tx = $self->c->db->txn_scope;

    my $row = $self->c->db->single('users', { name => $key_val });
    unless ($row) {
        $mres->content("no such user: name: $key_val");
        $mres->add_error({
            message => "no such user: name: $key_val",
            field   => 'users',
            code    => 'missing',
        });
        return $mres;
    }

    my $count = try {
        $row->update(\%newval);
    } catch {
        $mres->content('failed to update user');
        $mres->add_error({
            message => $_,
            field   => 'users',
            code    => 'fatal',
        });
        return;
    };
    unless (defined $count) {
        return $mres;
    }

    $mres = $self->search({
        q => [{ id => $row->get_column('id') }],
    });

    ### commit transaction
    $tx->commit;

    $mres->content( $mres->content->[0] );

    return $mres;
}

sub delete {
    my($self, $param) = @_;

    my $mres = <% $module %>::ModelResponse->new;

    my $rule = $self->c->validator(
        name => { isa => 'Str' },
    )->with('NoThrow');

    $param = $rule->validate(%$param);

    if ($rule->has_errors) {
        $mres->add_validator_errors($rule->clear_errors);
        return $mres;
    }

    my $count = $self->c->db->delete('users', $param);

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

    $self->content('validation failed');

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

=head1 STRUCTURE

    content => Any
      正常系の場合は任意の型のデータ
      異常系はエラーメッセージ:Str
    errors  => ArrayRef[ERROR]
    
    ERROR = {
      field   => エラー起因のパラメータやモデルの名前
      code    => missing | missing_field | invalid | already_exists | fatal
      message => Str (optional)
    }

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

use <% $module %>::Util;

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

    $self->write_file('lib/<<PATH>>/Redis.pm', <<'...', $tmpl_val);
package <% $module %>::Redis;

use strict;
use warnings;
use 5.010_000;
use utf8;

use Log::Minimal;
use Redis;
use Redis::Namespace;
use Redis::Key;

use <% $module %>::Util;

use Class::Accessor::Lite (
    new => 0,
    ro  => [qw(task status queue resource lock_launch)],
    rw  => [qw()],
);

sub new {
    my($class, $conf) = @_;

    my $redis = Redis->new(%$conf)
        or croakf 'failed to create Redis instance: %s', ddf($conf);

    my $self = bless {
        redis => $redis,
    }, $class;

    my $run_env = $ENV{PLACK_ENV} // 'localtest';
    for my $kind (qw(task status resource lock_launch)) {
        my $namespace = join ':', $run_env, '<% $distlc %>', $kind;
        my $ns = Redis::Namespace->new(
            redis     => $redis,
            namespace => $namespace,
        )
            or croakf 'failed to create Redis::Namespace: %s', $namespace;
        $self->{$kind} = $ns;
    }
    {
        my $namespace = join ':', $run_env, '<% $distlc %>';
        my $ns = Redis::Namespace->new(
            redis     => $redis,
            namespace => $namespace
        )
            or croakf 'failed to create Redis::Namespace: %s', $namespace;
        $self->{queue} = $ns;
    }

    return $self;
}

sub key {
    my($self, $kind, $param) = @_;

    my $key;
    if ($kind eq 'queue') {
        $key = 'queue';
    } elsif ($kind eq 'lock_launch') {
        croakf 'missing argument: hostname' unless $param->{hostname};
        $key = join ':', 'lock_launch', $param->{hostname};
    } else {
        my $ref = ref($param);
        if (!$ref) {
            $key = $param;
        } elsif ($ref eq 'HASH') {
            my @ke;
            for my $ke (qw(service hostname type)) {
                if ($param->{$ke}) {
                    push @ke, $param->{$ke};
                } else {
                    croakf 'missing argument: %s', $ke;
                }
            }
            $key = join ':', @ke;
        } else {
            croakf 'invalid argument: %s', ddf($param);
        }
    }

    debugf 'key: %s', $key;
    return Redis::Key->new(redis => $self->{$kind}, key => $key);
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

    $self->write_file('schema/config.yml', <<'...', $tmpl_val);
doc:
  toc: true
...

    $self->write_file('schema/meta.yml', <<'...', $tmpl_val);
---
id: meta
title: <% $dist %> API
description: <% $dist %> API
links:
  - href: https://fixme.example.com/v1
    rel: self
  - method: GET
    href: "/"
    rel: self
...

    $self->write_file('schema/schema.json', <<'...', $tmpl_val);
{
  "$schema": "http://interagent.github.io/interagent-hyper-schema",
  "type": [
    "object"
  ],
  "definitions": {
    "user": {
      "$schema": "http://json-schema.org/draft-04/hyper-schema",
      "title": "User",
      "description": "ユーザー操作",
      "stability": "prototype",
      "strictProperties": true,
      "type": [
        "object"
      ],
      "definitions": {
        "identity": {
          "anyOf": [
            {
              "$ref": "#/definitions/user/definitions/id"
            }
          ]
        },
        "id": {
          "description": "ユーザーID",
          "type": [
            "integer"
          ],
          "example": 31
        },
        "name": {
          "description": "ユーザー名",
          "type": [
            "string"
          ],
          "example": "hirose31"
        }
      },
      "properties": {
        "id": {
          "$ref": "#/definitions/user/definitions/id"
        },
        "name": {
          "$ref": "#/definitions/user/definitions/name"
        }
      },
      "links": [
        {
          "method": "GET",
          "href": "/users/{(%23%2Fdefinitions%2Fuser%2Fdefinitions%2Fname)}",
          "rel": "instance",
          "title": "Info",
          "description": "ユーザーの情報を返す",
          "targetSchema": {
            "$ref": "#/definitions/user"
          }
        },
        {
          "method": "POST",
          "href": "/users",
          "rel": "create",
          "title": "Register",
          "description": "ユーザーを登録する",
          "schema": {
            "type": [
              "object"
            ],
            "properties": {
              "name": {
                "$ref": "#/definitions/user/definitions/name"
              }
            }
          },
          "required": [
            "name"
          ],
          "targetSchema": {
            "$ref": "#/definitions/user"
          }
        },
        {
          "method": "PUT",
          "href": "/users/{(%23%2Fdefinitions%2Fuser%2Fdefinitions%2Fname)}",
          "rel": "update",
          "title": "Update",
          "description": "ユーザーの情報を変更する",
          "schema": {
            "type": [
              "object"
            ],
            "properties": {
              "name": {
                "$ref": "#/definitions/user/definitions/name"
              }
            }
          },
          "targetSchema": {
            "$ref": "#/definitions/user"
          }
        },
        {
          "method": "DELETE",
          "href": "/users/{(%23%2Fdefinitions%2Fuser%2Fdefinitions%2Fname)}",
          "rel": "destriy",
          "title": "Info",
          "description": "ユーザーを削除する",
          "targetSchema": {
            "$ref": "#/definitions/user"
          }
        }
      ]
    }
  },
  "properties": {
    "user": {
      "$ref": "#/definitions/user"
    }
  },
  "id": "meta",
  "title": "<% $dist %> API",
  "description": "<% $dist %> API",
  "links": [
    {
      "href": "https://fixme.example.com/v1",
      "rel": "self"
    },
    {
      "method": "GET",
      "href": "/",
      "rel": "self"
    }
  ]
}
...

    $self->write_file('schema/schemata/user.yml', <<'...', $tmpl_val);
---
"$schema": http://json-schema.org/draft-04/hyper-schema
id: schemata/user
title: User
description: ユーザー操作
stability: prototype
strictProperties: true
type:
- object

definitions:
  identity:
    anyOf:
    - "$ref": "/schemata/user#/definitions/id"
  id:
    description: ユーザーID
    type: integer
    example: 31
  name:
    description: ユーザー名
    type: string
    example: hirose31

properties:
  id:
    "$ref": "/schemata/user#/definitions/id"
  name:
    "$ref": "/schemata/user#/definitions/name"

links:
- method: GET
  href: "/users/{(%2Fschemata%2Fuser%23%2Fdefinitions%2Fname)}"
  rel: instance
  title: Info
  description: ユーザーの情報を返す
  targetSchema:
    "$ref": "/schemata/user"
- method: POST
  href: "/users"
  rel: create
  title: Register
  description: ユーザーを登録する
  schema:
    type: object
    properties:
      name:
        "$ref": "/schemata/user#/definitions/name"
  required:
  - "name"
  targetSchema:
    "$ref": "/schemata/user"
- method: PUT
  href: "/users/{(%2Fschemata%2Fuser%23%2Fdefinitions%2Fname)}"
  rel: update
  title: Update
  description: ユーザーの情報を変更する
  schema:
    type: object
    properties:
      name:
        "$ref": "/schemata/user#/definitions/name"
  targetSchema:
    "$ref": "/schemata/user"
- method: DELETE
  href: "/users/{(%2Fschemata%2Fuser%23%2Fdefinitions%2Fname)}"
  rel: destriy
  title: Info
  description: ユーザーを削除する
  targetSchema:
    "$ref": "/schemata/user"
...

    $self->write_file('script/<<DISTLC>>-api-server', <<'...', $tmpl_val);
#!perl

use strict;
use warnings;
use 5.010_000;
use utf8;

use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(__FILE__), '../lib');
use Plack::Builder;
use Plack::Builder::Conditionals;
use URI::Escape;
use File::Path ();
use Log::Minimal;

use <% $module %>;
use <% $module %>::API;

# time is not required, because I use multilog
# print pid for debugging
$Log::Minimal::PRINT = sub {
    my ( $time, $type, $message, $trace ) = @_;
    print STDERR "[$$] [$type] $message at $trace\n";
};

infof "Starting <% $module %> %s", $<% $module %>::VERSION;

my $app = builder {
    enable match_if addr(['10.33.4.0/22', '127.0.0.1']),
        'ReverseProxy';
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/static/)},
        root => File::Spec->catdir(dirname(__FILE__), '..');
    enable 'Plack::Middleware::Static',
        path => qr{^(?:/robots\.txt|/favicon\.ico)$},
        root => File::Spec->catdir(dirname(__FILE__), '..', 'static');

    <% $module %>::API->to_app();
};
unless (caller) {
    my $port        = 5000;
    my $host        = '127.0.0.1';
    my $max_workers = 4;

    require Getopt::Long;
    require Plack::Loader;
    my $p = Getopt::Long::Parser->new(
        config => [qw(posix_default no_ignore_case auto_help)]
    );
    $p->getoptions(
        'p|port=i'      => \$port,
        'host=s'        => \$host,
        'max-workers=i' => \$max_workers,
        'version!'      => \my $version,
        'c|config=s'    => \my $config_file,
    );
    if ($version) {
        print "<% $module %>: $<% $module %>::VERSION\n";
        exit 0;
    }
    if ($config_file) {
        my $config = do $config_file;
        Carp::croak("$config_file: $@") if $@;
        Carp::croak("$config_file: $!") unless defined $config;
        unless ( ref($config) eq 'HASH' ) {
            Carp::croak("$config_file does not return HashRef.");
        }
        no warnings 'redefine';
        no warnings 'once';
        *<% $module %>::load_config = sub { $config }
    }

    print "<% $module %>: http://${host}:${port}/\n";

    my $loader = Plack::Loader->load('Starlet',
        port        => $port,
        host        => $host,
        max_workers => $max_workers,
    );
    return $loader->run($app);
}
return $app;
...

    $self->write_file('service/<<DISTLC>>-api/env/.gitkeep', <<'...', $tmpl_val);
...

    $self->write_file('service/<<DISTLC>>-api/log/run', <<'...', $tmpl_val);
#!/bin/sh
logdir=./main
loguser=infra

if [ ! -d "$logdir" ] ; then
  install -d -o ${loguser} -m 2775 ${logdir} || exit 1
fi

exec setuidgid ${loguser} multilog t s999999 n10 ${logdir}
...

    $self->write_file('service/<<DISTLC>>-api/run', <<'...', $tmpl_val);
#!/bin/sh
exec 2>&1

### common preparation
run_file=$(readlink -f $0)
run_dir=${run_file%/*}

export APP_BASE=$(readlink -f $run_dir/../../)

export ENVDIR_INFRA="${run_dir}/env"

. /etc/infra.conf
infra_user=${INFRA_HOME##/*/}
PATH=${INFRA_ROOT}/bin:$PATH

echo $INFRA_ENV > $ENVDIR_INFRA/PLACK_ENV
if [[ ! -f "$ENVDIR_INFRA/RUN_MODE" ]]; then
  case $INFRA_ENV in
    *prod)
      echo 'production'  > $ENVDIR_INFRA/RUN_MODE
      ;;
    *)
      echo 'development' > $ENVDIR_INFRA/RUN_MODE
      ;;
  esac
fi

# open files
ulimit -n 32768

exec setuidgid $infra_user \
  sh -c '\
    export SHELL=/bin/sh; \
    export HOME=~infra
    export PERLBREW_ROOT=$HOME/perlbrew; \
    export PERLBREW_HOME=$HOME/perlbrew; \
    . $PERLBREW_ROOT/etc/bashrc; \
    exec \
      start_server \
      --port 5010 \
      --signal-on-term=TERM \
      --signal-on-hup=USR1 \
      --interval=10 \
      -- \
      envdir $ENVDIR_INFRA \
      sh -c "exec \
        carton exec -- \
        plackup \
          -s Starlet \
          -I $APP_BASE \
          --access-log /dev/null \
          --max-workers \${STARLET_MAX_WORKERS:-16} \
          --max-reqs-per-child \${STARLET_MAX_REQS_PER_CHILD:-1024} \
          --min-reqs-per-child \${STARLET_MIN_REQS_PER_CHILD:-512} \
          --spawn-interval \${STARLET_SPAWN_INTERVAL:-1} \
          $APP_BASE/script/<% $distlc %>-api-server \
"
'
...

    $self->write_file('sql/ddl.sql', <<'...', $tmpl_val);
CREATE TABLE IF NOT EXISTS users (
    id           INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    name         VARCHAR(255)
);
...

    $self->write_file('t/00_compile.t', <<'...', $tmpl_val);
use strict;
use warnings;
use Test::More;


use <% $module %>;
use <% $module %>::API;
use <% $module %>::API::View;
use <% $module %>::API::ViewFunctions;
use <% $module %>::API::Dispatcher;

use <% $module %>::DB::Schema;


pass "All modules can load.";

done_testing;
...

    $self->write_file('t/01_root.t', <<'...', $tmpl_val);
use strict;
use warnings;
use utf8;
use t::Util;
use Plack::Test;
use Plack::Util;
use Test::More;

my $app = Plack::Util::load_psgi 'script/<% $distlc %>-api-server';
test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => 'http://localhost/');
        my $res = $cb->($req);
        is $res->code, 200;
        diag $res->content if $res->code != 200;
    };

done_testing;
...

    $self->write_file('t/02_mech.t', <<'...', $tmpl_val);
use strict;
use warnings;
use utf8;
use t::Util;
use Plack::Test;
use Plack::Util;
use Test::More;
use Test::Requires 'Test::WWW::Mechanize::PSGI';

my $app = Plack::Util::load_psgi 'script/<% $distlc %>-api-server';

my $mech = Test::WWW::Mechanize::PSGI->new(app => $app);
$mech->get_ok('/');

done_testing;
...

    $self->write_file('t/Util.pm', <<'...', $tmpl_val);
package t::Util;
BEGIN {
    unless ($ENV{PLACK_ENV}) {
        $ENV{PLACK_ENV} = 'test';
    }
    if ($ENV{PLACK_ENV} eq 'production') {
        die "Do not run a test script on deployment environment";
    }
}
use File::Spec;
use File::Basename;
use lib File::Spec->rel2abs(File::Spec->catdir(dirname(__FILE__), '..', 'lib'));
use parent qw/Exporter/;
use Test::More 0.98;

our @EXPORT = qw(
    slurp
    validate_ipaddress
);

{
    # utf8 hack.
    binmode Test::More->builder->$_, ":utf8" for qw/output failure_output todo_output/;
    no warnings 'redefine';
    my $code = \&Test::Builder::child;
    *Test::Builder::child = sub {
        my $builder = $code->(@_);
        binmode $builder->output,         ":utf8";
        binmode $builder->failure_output, ":utf8";
        binmode $builder->todo_output,    ":utf8";
        return $builder;
    };
}


sub slurp {
    my $fname = shift;
    open my $fh, '<:encoding(UTF-8)', $fname or die "$fname: $!";
    scalar do { local $/; <$fh> };
}

sub validate_ipaddress {
    my $addr = shift;
    my $o1 = qr/2(?:5[0-5]|[0-4][0-9])|1[0-9]{2}|[1-9][0-9]|[1-9]/;
    my $o  = qr/2(?:5[0-5]|[0-4][0-9])|1[0-9]{2}|[1-9][0-9]|[0-9]/;
    $addr =~ /\A$o1\.$o\.$o\.$o\z/;
}

1;
...

    $self->write_file('t/harriet/mysqld.pl', <<'...', $tmpl_val);
use strict;
use warnings;
use utf8;

use FindBin;
use lib "$FindBin::Bin/../..";

use DBI;
use DBIx::FixtureLoader;
use Path::Class;
use Cwd;

use t::Util;

$ENV{TEST_MYSQL} ||= do {
    require Test::mysqld;

    my $cwd = Cwd::getcwd;

    my $copy_data_from = dir($ENV{TEST_MYSQL_COPY_DATA_FROM} // $cwd.'/tmp/test_mysql_copy_data_from');

    if (require_create_fixture($copy_data_from)) {
        create_fixture(
            cwd     => $cwd,
            datadir => $copy_data_from,
        );
    }

    my $mysqld = start_mysqld(
        copy_data_from => $copy_data_from,
    );

    $HARRIET_GUARDS::MYSQLD = $mysqld;
    $mysqld->dsn;
};

sub require_create_fixture {
    my($datadir) = @_;
    return -f $datadir->file('initialized') ? 0 : 1;
}

sub start_mysqld {
    my %args = @_;

    my $mysqld = Test::mysqld->new(
        my_cnf => {
            'skip-networking'        => '', # no TCP socket
            'performance_schema'     => 'off',
            'skip-secure-auth'       => '',
            'innodb_file_per_table'  => 1,
            'default-storage-engine' => 'InnoDB',
            'transaction-isolation'  => 'REPEATABLE-READ',
            # 'skip-character-set-client-handshake' => '',
            'character-set-server'   => 'utf8',
            ($args{datadir} ? (datadir => $args{datadir}) : ()),
        },
        ($args{copy_data_from} ? (copy_data_from => $args{copy_data_from}) : ()),
    ) or die $Test::mysqld::errstr;

    return $mysqld;
}

sub create_fixture {
    my %args = @_;
    my $datadir = $args{datadir};
    my $cwd     = $args{cwd};

    warn "create fixture\n";

    $datadir->rmtree(1);
    $datadir->mkpath(1, oct(2775)) or die $!;

    my $mysqld = start_mysqld(
        datadir => $datadir,
    );

    my $dbh = DBI->connect($mysqld->dsn) or die $DBI::errstr;

    warn "create schemata\n";
    my $ddl = slurp('sql/ddl.sql');
    for my $stmt (split /;/, $ddl) {
        next unless $stmt =~ /\S/;
        $dbh->do($stmt) or die $dbh->errstr;
    }

    $dbh->do('SET NAMES utf8');
    my $loader = DBIx::FixtureLoader->new(dbh => $dbh);
    for my $data (glob "$cwd/data/*.yaml") {
        warn "load data from $data\n";
        $loader->load_fixture($data);
    }

    undef $mysqld;

    $datadir->file('initialized')->touch;
}
...

    $self->write_file('t/http/users.t', <<'...', $tmpl_val);
use strict;
use warnings;
use utf8;
use Test::More;

use Plack::Test;
use Plack::Util;
use HTTP::Request::Common qw(GET POST DELETE PUT);
use JSON qw(encode_json decode_json);

use <% $module %>::Util;

my $app  = Plack::Util::load_psgi 'script/<% $distlc %>-api-server';
my $test = Plack::Test->create($app);

my $user_id;

subtest 'insert' => sub {
    my($res, $resource);

    $res = $test->request(POST '/v1/users',
                          'Content-Type' => 'application/json',
                          'Content' => encode_json({
                              name => 'hirose31',
                          }),
                      );
    ok $res->is_success, 'create user';
    $resource = decode_json($res->content);
    $user_id = $resource->{id};
    ok $user_id =~ /^[0-9]+$/;
    is $resource->{name}, 'hirose31';

    # idempotence
    $res = $test->request(POST '/v1/users',
                          'Content-Type' => 'application/json',
                          'Content' => encode_json({
                              name => 'hirose31',
                          }),
                      );
    ok $res->is_success, 'create user idempotence';
    $resource = decode_json($res->content);
    is $resource->{id}, $user_id;
};

subtest 'fetch' => sub {
    my($res, $resource);

    ### success
    $res = $test->request(GET "/v1/users/hirose31");
    ok $res->is_success, 'fetch user';
    $resource = decode_json($res->content);
    is $resource->{id}, $user_id;
    is $resource->{name}, 'hirose31';
};

subtest 'search' => sub {
    my($res, $resource);

    $res = $test->request(GET '/v1/search/users',
                          'Content-Type' => 'application/json',
                          'Content' => encode_json({
                              q => [{
                                  name => 'hirose31',
                              }],
                          }),
                      );
    ok $res->is_success, 'search user';
    $resource = decode_json($res->content);
    is scalar(@$resource), 1;
    ok $resource->[0]{id} =~ /^[0-9]+$/;
    is $resource->[0]{name}, 'hirose31';
};

subtest 'insert' => sub {
    my($res, $resource);

    $res = $test->request(PUT '/v1/users/hirose31',
                          'Content-Type' => 'application/json',
                          'Content' => encode_json({
                              name => 'hirose32',
                          }),
                      );
    ok $res->is_success, 'update user';
    $resource = decode_json($res->content);
    is $resource->{name}, 'hirose32';
};

subtest 'insert' => sub {
    my($res, $resource);

    $res = $test->request(DELETE '/v1/users/hirose32');
    ok $res->is_success, 'delete user';
    is $res->code, 204;
};

done_testing;
...

    $self->write_file('t/model/user.t', <<'...', $tmpl_val);
use strict;
use warnings;
use utf8;
use Test::More;

use FindBin;
use lib "$FindBin::Bin/../..";

use t::Util;
use <% $module %>::API;
use <% $module %>::Util;

my $c = <% $module %>::API->bootstrap();

subtest 'insert' => sub {
    my($mres, $resource);

    ### success
    $mres = $c->model('User')->insert({
        name => 'hirose31',
    });
    ok !$mres->has_errors;
    $resource = $mres->content;
    ok $resource->{id} =~ /^[0-9]+$/;
    is $resource->{name}, 'hirose31';

    ### fail
    $mres = $c->model('User')->insert();
    ok $mres->has_errors, 'no param';

    $mres = $c->model('User')->insert({
    });
    ok $mres->has_errors, 'no required param';
};

subtest 'fetch' => sub {
    my($mres, $resource);

    ### success
    $mres = $c->model('User')->fetch({
        name => 'hirose31',
    });
    ok !$mres->has_errors;
    $resource = $mres->content;
    is scalar(@$resource), 1;
    is $resource->[0]{name}, 'hirose31';

    $mres = $c->model('User')->fetch({
        name => 'blah blah blah',
    });
    ok !$mres->has_errors, 'not found';
    $resource = $mres->content;
    is scalar(@$resource), 0;

    ### fail
    $mres = $c->model('User')->fetch();
    ok $mres->has_errors, 'no param';

    $mres = $c->model('User')->fetch({
    });
    ok $mres->has_errors, 'no required param';
};

subtest 'search' => sub {
    my($mres, $resource);

    ### success
    $mres = $c->model('User')->search({
        q => [{
            name => 'hirose31',
        }],
    });
    ok !$mres->has_errors;
    $resource = $mres->content;
    is scalar(@$resource), 1;
    is $resource->[0]{name}, 'hirose31';

    $mres = $c->model('User')->search({
        q => [{
            name => ['hirose31'],
        }],
    });
    ok !$mres->has_errors, 'search by ArrayRef';
    $resource = $mres->content;
    is scalar(@$resource), 1;
    is $resource->[0]{name}, 'hirose31';

    $mres = $c->model('User')->search({
        q => [{
            name => 'blah blah blah',
        }],
    });
    ok !$mres->has_errors, 'not found';
    $resource = $mres->content;
    is scalar(@$resource), 0;

    ### fail
    $mres = $c->model('User')->search();
    ok $mres->has_errors, 'no param';

    $mres = $c->model('User')->search({
    });
    ok $mres->has_errors, 'no required param';
};

subtest 'update' => sub {
    my($mres, $resource);

    ### success
    $mres = $c->model('User')->update({
        key => 'hirose31',
        name => 'hirose32',
    });
    ok !$mres->has_errors;
    $resource = $mres->content;
    is $resource->{name}, 'hirose32';

    ### fail
    $mres = $c->model('User')->update();
    ok $mres->has_errors, 'no param';

    $mres = $c->model('User')->update({
    });
    ok $mres->has_errors, 'no required param';
};

subtest 'delete' => sub {
    my($mres, $resource);

    ### success
    $mres = $c->model('User')->delete({
        name => 'hirose32',
    });
    ok !$mres->has_errors;
    $resource = $mres->content;

    $mres = $c->model('User')->fetch({
        name => 'hirose32',
    });
    ok !$mres->has_errors;
    $resource = $mres->content;
    is_deeply $resource, [];

    ### fail
    $mres = $c->model('User')->delete();
    ok $mres->has_errors, 'no param';

    $mres = $c->model('User')->delete({
    });
    ok $mres->has_errors, 'no required param';
};


done_testing;
...

    $self->write_file('junk/myprove', <<'...', $tmpl_val);
#!/bin/bash

set -u
set -e
export LANG="C"

prog=${0##*/}
basedir=${0%/*}

env \
  RUN_MODE=${RUN_MODE:-development} \
  carton exec -- \
  prove "$@"
...
    chmod 0755, 'junk/myprove';

    $self->write_file('junk/mysock', <<'...', $tmpl_val);
#!/bin/bash
#
# export TEST_MYSQL='DBI:mysql:dbname=test;mysql_socket=/tmp/m1L8iR3XSD/tmp/mysql.sock;user=root'
# に基づいて sock で接続する

if [[ -z "$TEST_MYSQL" ]]; then
  echo "TEST_MYSQL not defined"
  exit 1
fi

eval "$(echo $TEST_MYSQL | tr ':;' '_ ')"
if [[ -z "$mysql_socket" ]]; then
  echo "missing mysql_socket: $TEST_MYSQL"
  exit 1
fi

if [[ ! -S "$mysql_socket" ]]; then
  echo "$mysql_socket is not socket"
  exit 1
fi

exec mysql -uroot -S $mysql_socket -D test "$@"
...
    chmod 0755, 'junk/mysock';

    $self->write_file('junk/start-api', <<'...', $tmpl_val);
#!/bin/bash

set -u
set -e
export LANG="C"

prog=${0##*/}
basedir=${0%/*}

env PLACK_ENV=development \
    RUN_MODE=development \
    LM_DEBUG=1 \
    carton exec -- \
    plackup -s Starlet -Ilib -I/home/hirose31/lib/plcmp/gi/ -R $basedir/../lib --access-log /dev/stdout -p 5010 $basedir/../script/<% $distlc %>-api-server  --host 0.0.0.0 \
    ;
...
    chmod 0755, 'junk/start-api';

    ### fix permission
    {
        for my $file (
          glob('service/*/run'),
          glob('service/*/log/run'),
        ) {
          chmod 0755, $file
        }
    }
    ### unlink
    {
        my @paths = (
            'lib/<% $path %>/Web/Plugin/',
            'sql/sqlite.sql',
            'sql/mysql.sql',
            't/03_assets.t',
            't/06_jshint.t',
        );

        for my $path (@paths) {
            $path = $self->render_string($path);
            system("rm -fr $path");
        }

    }
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
