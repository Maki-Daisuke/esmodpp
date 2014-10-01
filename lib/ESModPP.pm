package ESModPP;
our $VERSION = 0.10.1;

use strict;
no strict 'refs';
no warnings 'uninitialized';

use ESModPP::Parser;
use Exporter;
use Carp;
use File::Spec::Functions qw/catfile file_name_is_absolute/;

use base qw/Exporter ESModPP::Parser/;
our @EXPORT_OK   = qw/is_identifier parse_namespace version_cmp/;
our @EXPORT_TAGS = (all => \@EXPORT_OK);

use fields qw{
    _buffer
    _esmodpp
    _version
    _target
    _namespace
    _with
    _export
    _shared
    _require
    _extend
};

sub new : method {
    my $class = shift;
    my ESModPP $self = $class->SUPER::new;
    $self->{_buffer}    = "";
    $self->{_esmodpp}   = undef;     # true | false (undef means no @esmodpp directive has appeared.)
    $self->{_version}   = undef;     # /VERSION/ | undef (undef means no @version directive has appeared)
    $self->{_target}    = "GLOBAL";  # /NAMESPACE/
    $self->{_namespace} = {};        # {/NAMESPACE/ => [/IDENTIFIER/]}
    $self->{_with}      = [];        # [/NAMESPACE/]
    $self->{_export}    = {};        # {/IDENTIFIER/ => /NAMESPACE/}
    $self->{_shared}    = [];        # [{"namespace"=>/NAMESPACE/, "name"=>/IDENTIFIER/}]
    $self->{_require}   = {};        # {/NAMESPACE/ => /VERSPEC/}
    $self->{_extend}    = {};        # {/NAMESPACE/ => /VERSPEC/}
    $self;
}


my $re_version = qr{\d+(?:\.\d+)*};
my $re_verspec = qr{=$re_version|$re_version\+?};


my $croak = sub : method {
    my ESModPP $self = shift;
    croak @_, " at line ", $self->lineno;
};

my $register_ns = sub : method {
    my ESModPP $self = shift;
    my $ns = shift;
    my @id = parse_namespace($ns)  or $self->$croak("Invalid namespace: `$ns'");
    $ns = join ".", @id;
    $self->{_namespace}{$ns} = \@id;
    $ns;
};

my $duplicate_check = sub : method {
    my ESModPP $self = shift;
    my ($module, $version) = @_;
    $module = join ".", parse_namespace($module)    or $self->$croak("Invalid module name: `$module'");
    if ( length $version ) {
        $self->$croak("Invalid version-specifier: `$version'")  unless $version =~ /^$re_verspec$/o;
        if ( defined $self->{_require}{$module}  and  $self->{_require}{$module} ne $version ) {  # version of `undef' does not restrict module version.
            $self->$croak("`$module' is already required with version $self->{_require}{$module}, but required again with version $version.");
        }
        if ( defined $self->{_extend}{$module}  and  $self->{_extend}{$module} ne $version ) {
            $self->$croak("`$module' is already required with version $self->{_extend}{$module}, but required again with version $version.");
        }
    }
    ($module, $version);
};

sub version : method {
    my ESModPP $self = shift;
    $self->{_version};
}

sub active : method {
    my ESModPP $self = shift;
    $self->{_esmodpp};
}

sub write : method {
    my ESModPP $self = shift;
    $self->{_buffer} .= join "", @_;
}

sub result : method {
    my ESModPP $self = shift;
    return $self->{_buffer}  unless defined $self->{_esmodpp};
    my $buf = "(function(){\n";  # Top-level closure, which ensures that this-value refers the Global Object.
    foreach ( values %{$self->{_namespace}} ) {
        my @names = @$_;
        my $name = "this";
        while ( @names ) {
            $name .= "." . shift @names;
            $buf .= "    if ( !$name || (typeof $name != 'object' && typeof $name != 'function') ) $name = new Object();\n";
        }
    }
    foreach ( @{$self->{_shared}} ) {
        local $_ = $_->{namespace} eq "GLOBAL" ? $_->{name} : "$_->{namespace}.$_->{name}";
        $buf .= "    if ( this.$_ === undefined ) this.$_ = undefined;\n";
    }
    $buf .= "with ( function(){\n";
    foreach ( reverse @{$self->{_with}} ) {
        $buf .= "with ( $_ ) {\n";
    }
    $buf .= qq{
        return function () {
            var VERSION @{[ defined $self->{_version} ? "= '$self->{_version}'" : "" ]};
            var NAMESPACE;
            @{[ $self->{_buffer} ]}
            return {
                @{[ join ", ", map{"$_: $_"} keys %{$self->{_export}} ]}
            };
        }();
    };
    $buf .= "}\n" x @{$self->{_with}};
    $buf .= "}.call(null) ) {\n";
    while ( my ($name, $ns) = each %{$self->{_export}} ) {
        $ns = $ns eq "GLOBAL" ? $name : "$ns.$name";
        $buf .= "    this.$ns = $name;\n";
    }
    $buf .= "}\n";     # End of with
    $buf .= "}).call(null);\n";  # The end of the top-level closure.
    $buf;
}

sub require : method {
    my ESModPP $self = shift;
    return { %{$self->{_require}} };
}

sub extend : method {
    my ESModPP $self = shift;
    return { %{$self->{_extend}} };
}


sub directive : method {
    my ESModPP $self = shift;
    if ( $self->{_esmodpp}  or  $_[0] eq '@esmodpp' ) {
        $self->SUPER::directive(@_);
    } else {
        $self->write($_[2]);
    }
}

sub text : method {
    (my ESModPP $self, my $text) = @_;
    $self->write($text);
}

*{__PACKAGE__.'::@esmodpp'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    my $text = shift;
    if ( @args ) {
        $self->$croak('@esmodpp takes at most one argument')                                 unless @args == 1;
        local $_ = shift @args;
        if ( /^off$/i ) {
            if ( $self->{_esmodpp} ) { $self->{_esmodpp} = "" }
            else                     { $self->write($text)    }
            return;
        }
        $self->$croak("Invalid version string: `$_'")                                        unless /^$re_version$/o;
        $self->$croak(sprintf "ESModPP %s is required, but this is only %vd", $_, $VERSION)  if version_cmp($_, $VERSION) > 0;
    }
    $self->{_esmodpp} = 1;
};

*{__PACKAGE__.'::@version'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    $self->$croak('@version takes just one argument')  unless @args == 1;
    local $_ = shift @args;
    $self->$croak("Invalid version string: `$_'")      unless /^$re_version$/o;
    $self->$croak('@version appears more than once')   if defined $self->{_version};
    $self->{_version} = $_;
};

*{__PACKAGE__.'::@use-namespace'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    $self->$croak('@use-namespace takes just one argument')  unless @args == 1;
    my $ns = $args[0] eq "GLOBAL" ? "GLOBAL" : $self->$register_ns($args[0]);
    $self->{_target} = $ns;
    $self->write("NAMESPACE = '$ns';\n");
};

*{__PACKAGE__.'::@with-namespace'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    $self->$croak('@with-namespace requires one or more arguments')  unless @args;
    foreach ( @args ) {
        if ( $_ eq "GLOBAL" ) {
            push @{$self->{_with}}, 'this';
        } else {
            my $ns = $self->$register_ns($_);
            push @{$self->{_with}}, $ns;
        }
    }
};

*{__PACKAGE__.'::@namespace'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    my $text = shift;
    $self->$croak('@namespace takes just one argument.')  unless @args == 1;
    my $use  = '@use-namespace';
    my $with = '@with-namespace';
    $self->$use(\@args, $text);
    $self->$with(\@args, $text);
};

*{__PACKAGE__.'::@export'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    my $target = $self->{_target};
    foreach ( @args ) {
        $self->$croak("Invalid identifier: `$_'")  unless is_identifier($_);
        $self->$croak("Redundantly exported symbol: `$_'")  if exists ${$self->{_export}}{$_};
        push @{$self->{_shared}}, {namespace=>$target, name=>$_};
        ${$self->{_export}}{$_} = $target;
    }
};

*{__PACKAGE__.'::@shared'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    my $target = $self->{_target};
    foreach ( @args ) {
        $self->$croak("Invalid identifier: `$_'")  unless is_identifier($_);
        push @{$self->{_shared}}, {namespace=>$target, name=>$_};
    }
};

*{__PACKAGE__.'::@include'} = sub : method {
    my ESModPP $self = shift;
    my @args = @{shift()};
    $self->$croak('@include requires one or more arguments.')  unless @args;
    foreach my $file ( @args ) {
        local *FILE;
        OPEN: unless ( open FILE, $file ) {
            unless ( file_name_is_absolute $file ) {
                foreach ( split /;/, $ENV{ES_INCLUDE} ) {
                    open(FILE, catfile $_, $file) and last OPEN;
                }
            };
            $self->$croak("Can't open included file `$file': $!");
        }
        read FILE, my $text, (stat FILE)[7];
        close FILE;
        $self->unread($text);
    }
};

*{__PACKAGE__.'::@require'} = sub {
    my ESModPP $self = shift;
    my @args = @{shift()};
    $self->$croak('@require requires at least one argument.')  unless @args;
    $self->$croak('@require takes at most two arguments.')     if @args > 2;
    my ($module, $version) = $self->$duplicate_check(@args);
    $self->{_require}{$module} = $version;
};

*{__PACKAGE__.'::@extend'} = sub {
    my ESModPP $self = shift;
    my @args = @{shift()};
    $self->$croak('@extend requires at least one argument.')  unless @args;
    $self->$croak('@extend takes at most two arguments.')     if @args > 2;
    my ($module, $version) = $self->$duplicate_check(@args);
    $self->{_extend}{$module} = $version;
};



my $UnicodeLetter         = '\p{IsLu}\p{IsLl}\p{IsLt}\p{IsLm}\p{IsLo}\p{IsNl}';
my $UnicodeEscapeSequence = qr{\\u[0-9a-fA-F]{4}};
my $IdentifierStart       = qr{[\$_$UnicodeLetter]|$UnicodeEscapeSequence};
my $IdentifierPart        = qr{[\$_$UnicodeLetter\p{IsMn}\p{IsMc}\p{IsNd}\p{IsPc}]|$UnicodeEscapeSequence};
my $Identifier            = qr{(?>$IdentifierStart$IdentifierPart*)};

my %reserved = map{ $_ => 1 } qw{
    break     else        new        var
    case      finally     return     void
    catch     for         switch     while
    continue  function    this       with
    default   if          throw
    delete    in          try
    do        instanceof  typeof
    abstract  enum        int        short
    boolean   export      interface  static
    byte      extends     long       super
    char      final       native     synchronized
    class     float       package    throws
    const     goto        private    transient
    debugger  implements  protected  volatile
    double    import      public
};

sub is_identifier ($) {
    local $_ = shift;
    /^$Identifier$/o  and  not exists $reserved{$_};
}

sub parse_namespace ($) {
    local $_ = shift;
    my @id;
    foreach ( split /\./ ) {
        return unless is_identifier $_;
        push @id, $_;
    }
    return unless @id;
    @id;
}


sub split_version {
    local $_ = shift;
    $_ = sprintf "%vd", $_  unless /^$re_version$/o;
    split /\./;
}

sub version_cmp {
    my @l = split_version shift;
    my @r = split_version shift;
    while ( @l || @r ) {
        my $cmp = shift @l <=> shift @r;
        return $cmp  if $cmp;
    }
    return 0;
}


1;
__END__

=encoding utf-8

=head1 NAME

ESModPP - EcmaScript Modularizing Pre-Processor

=head1 SYNOPSIS

カレントディレクトリに次の２つのファイルがあるとします:

my/module.js:

    //@esmodpp
    //@namespace my.module

    //@export exported_func
    function exported_func ( x ) {
      alert("Hello, " + x);
    }

me.js:

    //@esmodpp
    //@require my.module

    exported_func("world");

この状態でコマンドラインで次のように実行しましょう:

    ES_LIB=./ escat me.js > out.js

すると、out.js の中身は次のようになります:

    (function(){
        if ( !this.my || (typeof this.my != 'object' && typeof this.my != 'function') ) this.my = new Object();
        if ( !this.my.module || (typeof this.my.module != 'object' && typeof this.my.module != 'function') ) this.my.module = new Object();
        if ( this.my.module.exported_func === undefined ) this.my.module.exported_func = undefined;
    with ( function(){
    with ( my.module ) {

            return function () {
                var VERSION ;
                var NAMESPACE;


    NAMESPACE = 'my.module';



    function exported_func ( x ) {
      alert("Hello, " + x);
    }

                return {
                    exported_func: exported_func
                };
            }();
        }
    }.call(null) ) {
        this.my.module.exported_func = exported_func;
    }
    }).call(null);
    (function(){
    with ( function(){

            return function () {
                var VERSION ;
                var NAMESPACE;




    exported_func("world");

                return {

                };
            }();
        }.call(null) ) {
    }
    }).call(null);

このコードは（おそらく）おなたの期待しているとおりに動くでしょう。

=head1 DESCRIPTION

ESModPP は主に Concurrent.Thread をビルドするために作られた古のツールです。

B<他の目的には決して利用しないでください。>

=head1 INSTALLATION

  git clone https://github.com/Maki-Daisuke/esmodpp.git
  cd esmodpp
  perl Build.PL
  ./Build install

or

  cpanm git://github.com/Maki-Daisuke/esmodpp.git

=head1 SPECIFICATION

esmodpp仕様 ver. 0.9.2

=head2 Goals and Rationales

esmodppは次に挙げる目標を目指す、或いは目指さないこととする。

=over

=item 第一に、ECMAScriptによるプログラムにおいて階層化された名前空間を提供する。

esmodppの目指すところは、EcmaScript MODularizing PreProcessorである。
プログラムをモジュール化するためには、変数を書き散らかさないよう、
モジュールごとに制御可能な名前空間が必要であろう。

=item esmodppを利用していないECMAScriptプログラムには影響を与えないようにする。

これにより、既存のライブラリとの協調性を確保する。

=item ファイルの中で宣言された変数（関数）はファイルの中でプライベートにする。

いわゆるファイルスコープを提供することで、ファイル中で自由気ままに、
かつ安全に変数を使えるようにする。
これは関数間で変数を共有したい場合に特に有効である。

=item ファイルと名前空間を一対一で対応付けることはしない。

１つのファイルの中でいくつでも名前空間を使えるようにすることで、
異なる名前空間に存在する関数の間で、ファイルスコープを持つプライベートな
変数を共有できるようにする。
また、複数のファイルから１つの名前空間を何度でも使えるようにすることで、
規模の大きいパッケージを、いくつかのファイルに分けて開発できるようにする。

=item ソースコードをパージングしない。

なぜなら、一度ECMAScriptの構文解析に立ち入れば、実装系（主にWebブラウザ）間の
独自拡張の底なし沼に足を踏み入れることになるからだ。
この制約によって、esmodpp自体は特定のブラウザに依存することなく、また、
プログラマには任意のブラウザに依存したコーディングを可能とする。
よって、構文解析が必要となる機能（たとえばマクロ）は一切サポートしない。

=item ディレクティブを含んだECMAScriptプログラムを、構文的に正しいECMAScriptプログラムであるようにする。

一般に、プログラムコード片の行位置はプリプロセスの前後で保存されない。
そのため、プリプロセッサにかける前にブラウザで構文チェックができることは、
煩雑な（しかも退屈な）シンタックスエラーの修正の際に役立つ。

=item 標準に準拠する。

ECMA-262 3rd ed.に準拠し、プリプロセッサが生成するコードはすべてこれの許容する範囲とする。
これにより、実装系の間での互換性を確保する。

=item 簡便で一貫性・拡張性のある記法を採用する。

ディレクティブの構文を一貫させることで、命令の追加を容易にする。

=back

=head2 Syntax

esmodppは、プログラムソースコードから下で定義される C<E<lt>directiveE<gt>> にマッチする
シークエンスをディレクティブとして扱う。

  <directive> ::
    <line-head> <white-space>* '//@' <name> <arguments> <white-space>* <end-of-line>

  <line-head>
    is a position where a logical line begins in source file.
    It is the head of a file or just after <line-terminator>.

  <line-terminator>
    is one of the followings.
    LF -- line feed           (¥u000A)
    CR -- carriage return     (¥u000D)
    LS -- line separator      (¥u2028)
    PS -- paragraph separator (¥u2029)

  <name> ::
    <name-character>+

  <name-character> :: one of
    'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm'
    'n' 'o' 'p' 'q' 'r' 's' 't' 'u' 'v' 'w' 'x' 'y' 'z'
    'A' 'B' 'C' 'D' 'E' 'F' 'G' 'H' 'I' 'J' 'K' 'L' 'M'
    'N' 'O' 'P' 'Q' 'R' 'S' 'T' 'U' 'V' 'W' 'X' 'Y' 'Z'
    '0' '1' '2' '3' '4' '5' '6' '7' '8' '9' '-' '_'

  <white-space>
    is one of the followings:
    HT   -- horizontal tab (¥u0009)
    VT   -- vertical tab   (¥u000B)
    FF   -- form feed      (¥u000C)
    SP   -- space          (¥u0020)
    NBSP -- no-break space (¥u00A0)
    Any other category "Zs".

  <end-of-line>
    is a position where a logical line ends in source file.
    It is the end of a file or just before <line-terminator>.

  <arguments> ::
    <null-string>
    <arguments> <white-space>+ <argument>

  <null-string>
    is the string whose length is zero.

  <argument> ::
    <literal>
    <quoted>

  <literal> ::
    <literal-head> <literal-character>

  <literal-head> ::
    Any character except <line-terminator>, <white-space>, "'" and '"'.

  <literal-character> ::
    Any character except <line-terminator> and <white-space>.

  <quoted> ::
    ''' <single-quoted-character> "'"
    '"' <double-quoted-character> '"'

  <single-quoted-character> ::
    Any character except <line-terminator> and "'".
    "''"

  <double-quoted-character> ::
    Any character except <line-terminator> and '"'.
    '""'


=head2 Instructions

次にあげるものがディレクティブとして定義されている。

=over

=item C<//@esmodpp [VERSION]>

=item C<//@esmodpp off>

このディレクティブ以降のプログラムソースを、esmodppを使ってプリプロセスすることを宣言する。
省略可能の C<VERSION> を指定すると、C<VERSION> 以上のesmodpp仕様に対応していることを要求する。
VERSIONは１つ以上の整数文字列をドット(C<.>)で連結したものである。
（使用されている実装が C<VERSION> に対応していない場合の挙動は、実装に依る。）
C<//@esmodpp off> と合わせて使うことで、プリプロセッサの on/off を切り替えられる。
このディレクティブが書かれていないソースファイルはプリプロセスされることを免れる。

=item C<//@version VERSION>

このモジュールのバージョンを指定する。
C<VERSION> で指定された文字列をファイルスコープ変数 C<VERSION> にセットする。
C<VERSION> は１つ以上の整数をドット(C<.>)で連結したものである。

=item C<//@use-namespace NAMESPACE>

このディレクティブ以降のソースコードで、C<@export> ディレクティブと C<@shared> ディレクティブの
ターゲットとなる名前空間を宣言する。また、ここで指定された文字列を、ファイルスコープ変
数 C<NAMESPACE> に設定する。
C<NAMESPACE> は、１つ以上のECMAScriptの識別子をドット(C<.>)で連結したものである。
C<NAMESPACE> に C<GLOBAL> が指定された場合には特別な意味を持つ。この場合、ターゲット名前空間
として「The Global Object」が選択されたことを意味する。
デフォルトのターゲット名前空間は C<GLOBALで> ある。
※モジュール内での C<var> や C<function> がここで指定した名前空間に変数を宣言するわけではない
ことに注意すること。 C<var>や C<function> による宣言は常にモジュール内でプライベートな
スコープを持つ。名前空間に変数を作るには C<@export>と C<@shared> を使う。
また、 C<@use-namespace> で指定した名前空間がモジュール内でスコープ解決に使われる
わけではないことにも注意。このようなことがしたい場合には C<@namespace> を用いる。

=item C<//@export NAME [, NAME ...]>

C<NAME>で指定された識別子とそれが指す値を、 C<@use-namespace> ディレクティブで宣言された名前空間に
エクスポートする。
C<NAME> は ECMAScript での識別子である。
宣言された名前はモジュールの評価前に名前空間に定義されるが、
値が代入されるのはモジュールの評価後である。
※これは変数をエクスポートするわけではないことに注意すること。
具体的には、モジュールを評価した後にそのスコープでNAMEで得られる値を、
名前空間の変数・NAMEに代入する。
よって、名前空間にエクスポートされた変数の値がモジュールの外部から変更されたとしても、
その変更はモジュールの内部からは見えない。つまり、関数をエクスポートすることによって
カプセル化が破壊されることはない。
名前空間を介してモジュールの外部と変数を共有したい場合には@sharedを用いる。

=item C<//@shared NAME [, NAME ...]>

C<@use-namespace> で宣言された名前空間に変数を宣言する。
※C<@shared> で宣言された変数がモジュール内で無修飾で参照できるとは限らない点に注意。
無修飾で参照したい場合は、 C<@use-namespace> で宣言された名前空間を
C<@with-namespace> でも併せて宣言すれば良い。

=item C<//@with-namespace NAMESPACE [, NAMESPACE, ...]>

このモジュール内でスコープ解決に使用する名前空間を宣言する。
スクリプトを実行する際に、C<NAMESPACE>で指定された名前空間がスコープチェインの
先頭に付加されて評価される。
C<NAMESPACE>に C<GLOBAL> が指定された場合には特別な意味を持つ。この場合、スコープチェイン
の先頭に「The Global Object」が付加される。
C<@with-namespace> で複数の名前空間が指定された場合には前に書かれた名前空間が、
また C<@with-namespace> が複数使われた場合には先に宣言された名前空間が優先される。
C<@with-namespace> 宣言はファイルスコープを持つ。つまりこのディレクティブがソースコード中の
どこに書かれていようと、指定された名前空間はファイルの先頭でもスコープ解決に
用いられる。
C<var> や C<function> などでモジュール内で宣言された変数は、常にこのディレクティブで追加された
スコープよりも高い優先順位を持つ。

=item C<//@namespace NAMESPACE>

次のシンタックスシュガー:

  //@use-namespace NAMESPACE
  //@with-namespace NAMESPACE

=item C<//@include FILE [, FILE ...]>

C<FILE> で指定されたファイルの内容をこの場所に展開する。
C<FILE> が相対パスだった場合、カレントディレクトリから探して見つからなかったら、
環境変数 ES_INCLUDE に列記されたディレクトリからファイルを探す。

=back

=head1 LICENSE

Copyright (C) Daisuke (yet another) Maki.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Daisuke (yet another) Maki E<lt>maki.daisuke@gmail.comE<gt>

=cut
