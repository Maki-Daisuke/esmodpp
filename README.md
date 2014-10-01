# NAME

ESModPP - EcmaScript Modularizing Pre-Processor

# SYNOPSIS

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

# DESCRIPTION

ESModPP は主に Concurrent.Thread をビルドするために作られた古のツールです。

**他の目的には決して利用しないでください。**

# INSTALLATION

    git clone https://github.com/Maki-Daisuke/esmodpp.git
    cd esmodpp
    perl Build.PL
    ./Build install

or

    cpanm git://github.com/Maki-Daisuke/esmodpp.git

# SPECIFICATION

esmodpp仕様 ver. 0.9.2

## Goals and Rationales

esmodppは次に挙げる目標を目指す、或いは目指さないこととする。

- 第一に、ECMAScriptによるプログラムにおいて階層化された名前空間を提供する。

    esmodppの目指すところは、EcmaScript MODularizing PreProcessorである。
    プログラムをモジュール化するためには、変数を書き散らかさないよう、
    モジュールごとに制御可能な名前空間が必要であろう。

- esmodppを利用していないECMAScriptプログラムには影響を与えないようにする。

    これにより、既存のライブラリとの協調性を確保する。

- ファイルの中で宣言された変数（関数）はファイルの中でプライベートにする。

    いわゆるファイルスコープを提供することで、ファイル中で自由気ままに、
    かつ安全に変数を使えるようにする。
    これは関数間で変数を共有したい場合に特に有効である。

- ファイルと名前空間を一対一で対応付けることはしない。

    １つのファイルの中でいくつでも名前空間を使えるようにすることで、
    異なる名前空間に存在する関数の間で、ファイルスコープを持つプライベートな
    変数を共有できるようにする。
    また、複数のファイルから１つの名前空間を何度でも使えるようにすることで、
    規模の大きいパッケージを、いくつかのファイルに分けて開発できるようにする。

- ソースコードをパージングしない。

    なぜなら、一度ECMAScriptの構文解析に立ち入れば、実装系（主にWebブラウザ）間の
    独自拡張の底なし沼に足を踏み入れることになるからだ。
    この制約によって、esmodpp自体は特定のブラウザに依存することなく、また、
    プログラマには任意のブラウザに依存したコーディングを可能とする。
    よって、構文解析が必要となる機能（たとえばマクロ）は一切サポートしない。

- ディレクティブを含んだECMAScriptプログラムを、構文的に正しいECMAScriptプログラムであるようにする。

    一般に、プログラムコード片の行位置はプリプロセスの前後で保存されない。
    そのため、プリプロセッサにかける前にブラウザで構文チェックができることは、
    煩雑な（しかも退屈な）シンタックスエラーの修正の際に役立つ。

- 標準に準拠する。

    ECMA-262 3rd ed.に準拠し、プリプロセッサが生成するコードはすべてこれの許容する範囲とする。
    これにより、実装系の間での互換性を確保する。

- 簡便で一貫性・拡張性のある記法を採用する。

    ディレクティブの構文を一貫させることで、命令の追加を容易にする。

## Syntax

esmodppは、プログラムソースコードから下で定義される `<directive>` にマッチする
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

## Instructions

次にあげるものがディレクティブとして定義されている。

- `//@esmodpp [VERSION]`
- `//@esmodpp off`

    このディレクティブ以降のプログラムソースを、esmodppを使ってプリプロセスすることを宣言する。
    省略可能の `VERSION` を指定すると、`VERSION` 以上のesmodpp仕様に対応していることを要求する。
    VERSIONは１つ以上の整数文字列をドット(`.`)で連結したものである。
    （使用されている実装が `VERSION` に対応していない場合の挙動は、実装に依る。）
    `//@esmodpp off` と合わせて使うことで、プリプロセッサの on/off を切り替えられる。
    このディレクティブが書かれていないソースファイルはプリプロセスされることを免れる。

- `//@version VERSION`

    このモジュールのバージョンを指定する。
    `VERSION` で指定された文字列をファイルスコープ変数 `VERSION` にセットする。
    `VERSION` は１つ以上の整数をドット(`.`)で連結したものである。

- `//@use-namespace NAMESPACE`

    このディレクティブ以降のソースコードで、`@export` ディレクティブと `@shared` ディレクティブの
    ターゲットとなる名前空間を宣言する。また、ここで指定された文字列を、ファイルスコープ変
    数 `NAMESPACE` に設定する。
    `NAMESPACE` は、１つ以上のECMAScriptの識別子をドット(`.`)で連結したものである。
    `NAMESPACE` に `GLOBAL` が指定された場合には特別な意味を持つ。この場合、ターゲット名前空間
    として「The Global Object」が選択されたことを意味する。
    デフォルトのターゲット名前空間は `GLOBALで` ある。
    ※モジュール内での `var` や `function` がここで指定した名前空間に変数を宣言するわけではない
    ことに注意すること。 `var`や `function` による宣言は常にモジュール内でプライベートな
    スコープを持つ。名前空間に変数を作るには `@export`と `@shared` を使う。
    また、 `@use-namespace` で指定した名前空間がモジュール内でスコープ解決に使われる
    わけではないことにも注意。このようなことがしたい場合には `@namespace` を用いる。

- `//@export NAME [, NAME ...]`

    `NAME`で指定された識別子とそれが指す値を、 `@use-namespace` ディレクティブで宣言された名前空間に
    エクスポートする。
    `NAME` は ECMAScript での識別子である。
    宣言された名前はモジュールの評価前に名前空間に定義されるが、
    値が代入されるのはモジュールの評価後である。
    ※これは変数をエクスポートするわけではないことに注意すること。
    具体的には、モジュールを評価した後にそのスコープでNAMEで得られる値を、
    名前空間の変数・NAMEに代入する。
    よって、名前空間にエクスポートされた変数の値がモジュールの外部から変更されたとしても、
    その変更はモジュールの内部からは見えない。つまり、関数をエクスポートすることによって
    カプセル化が破壊されることはない。
    名前空間を介してモジュールの外部と変数を共有したい場合には@sharedを用いる。

- `//@shared NAME [, NAME ...]`

    `@use-namespace` で宣言された名前空間に変数を宣言する。
    ※`@shared` で宣言された変数がモジュール内で無修飾で参照できるとは限らない点に注意。
    無修飾で参照したい場合は、 `@use-namespace` で宣言された名前空間を
    `@with-namespace` でも併せて宣言すれば良い。

- `//@with-namespace NAMESPACE [, NAMESPACE, ...]`

    このモジュール内でスコープ解決に使用する名前空間を宣言する。
    スクリプトを実行する際に、`NAMESPACE`で指定された名前空間がスコープチェインの
    先頭に付加されて評価される。
    `NAMESPACE`に `GLOBAL` が指定された場合には特別な意味を持つ。この場合、スコープチェイン
    の先頭に「The Global Object」が付加される。
    `@with-namespace` で複数の名前空間が指定された場合には前に書かれた名前空間が、
    また `@with-namespace` が複数使われた場合には先に宣言された名前空間が優先される。
    `@with-namespace` 宣言はファイルスコープを持つ。つまりこのディレクティブがソースコード中の
    どこに書かれていようと、指定された名前空間はファイルの先頭でもスコープ解決に
    用いられる。
    `var` や `function` などでモジュール内で宣言された変数は、常にこのディレクティブで追加された
    スコープよりも高い優先順位を持つ。

- `//@namespace NAMESPACE`

    次のシンタックスシュガー:

        //@use-namespace NAMESPACE
        //@with-namespace NAMESPACE

- `//@include FILE [, FILE ...]`

    `FILE` で指定されたファイルの内容をこの場所に展開する。
    `FILE` が相対パスだった場合、カレントディレクトリから探して見つからなかったら、
    環境変数 ES\_INCLUDE に列記されたディレクトリからファイルを探す。

# LICENSE

Copyright (C) Daisuke (yet another) Maki.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Daisuke (yet another) Maki <maki.daisuke@gmail.com>
