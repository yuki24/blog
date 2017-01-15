---
layout: post
title:  did_you_mean gem はどう動いているか
date:   2015-03-08 12:20:06
categories: engineering
location: New York, United States
tags: ruby did_you_mean
---

本腰を入れて `did_you_mean` gem の開発に取り組むようになったのは、今記事を書いている2015年3月からちょうど1年程前のことである。最初は、とりあえず動く実装を作って gem を公開し、実際に仕事で試して自分自身が感じる使い心地や、周囲のエンジニアからのフィードバックを聞いていった。すると、思った以上に良いフィードバックが多く、実際に「助かったよ、ありがとう！」という声もあった。それから少しづつ変更を加えていき、そろそろ普通に使えるようになったと感じた2014年9月に Qiita を記事を公開した。さらにその後、多くの日本人エンジニアからのフィードバックやいくつか pull request を取り込んだ後、英語でも同様の記事を書き Hacker News へ投稿した。日本語圏でも英語圏でもたくさんのフィードバックを頂くことができてとても嬉しかったし、フィードバックをくれた全ての人に感謝している。

では、いったい何が `did_you_mean` gem を作るきっかけになったのか。

# なぜ作ったのか

どのグループかは忘れてしまったが、Facebook 上で「kaminariが動かない。`NoMethodError` になってしまう」というコメントを見つけた。自分は kaminari のメンセナンスをやっているので、自分に何か助けられることはないかと返信をした。しかし、色々調べてみても `NoMethodError` の原因は分からかった。数時間後、実はメソッドの名前が間違っていたために動いてないことが判明した。[@kysnm](https://twitter.com/kysnm) さんはそのことを [Qiita へ投稿している](http://qiita.com/kysnm/items/50f97213196cd031358e)。

このような経験は初めてではなかったので、Google や Git のように Ruby が正しい名前を教えてくれたらいいのに、と強く感じた。これがモチベーションとなって、`did_you_mean` の開発を始めることにした。

# どうやって動いているのか

`did_you_mean` の仕組みを単純なスニペットとしてまとめてみた。例として、`String` クラスに定義されている `#start_with?` メソッドを `#starts_with?` としてしまった場合を想定する。前者は Ruby が提供するメソッドだが、後者は[ActiveSupport が提供するメソッド](https://github.com/rails/rails/blob/c0bb4c6ed/activesupport/lib/active_support/core_ext/string/starts_ends_with.rb#L2)なので、間違いやすい。

```ruby
module Levenshtein
  def self.distance(str1, str2)
    str1, str2 = str1.to_s, str2.to_s

    # calculates edit distance...
  end
end

string    = "Yuki Nishijima"
threshold = 2

begin
  string.starts_with?("Yuki")
rescue NoMethodError => error
  suggestions = string.methods.select do |method_name|
    Levenshtein.distance(method_name, error.name) < threshold
  end
end

puts suggestions
# => [:start_with?]
```

このコードは特に難しいことをやっていないが、ポイントは3つある。

 * [`str.methods`](http://ruby-doc.org/core-2.2.1/Object.html#method-i-methods) でメソッドのリストを取り出している
 * [`error.name`](http://ruby-doc.org/core-2.2.1/NameError.html#method-i-name) で何がタイプされたのかを取り出している
 * [Levenshtein アルゴリズム](http://en.wikipedia.org/wiki/Levenshtein_distance) で文字列間の距離を計算し、しきい値以下であったら候補とみなす

たったこれだけのコードだが、`#start_with?` という正しいメソッド名を探し出すことに成功している。そして、今日における `did_you_mean` gem は（`NoMethodError`の場合）本当にこれだけのコードでメソッドを探している。

一方で、実際に開発者がスペルミスをした時に得られるエラーメッセージは少しだけ違う。

```ruby
require "did_you_mean"

"Yuki Nishijima".starts_with?("Yuki")
# => NoMethodError: undefined method `starts_with?' for "Yuki Nishijima":String
#
#    Did you mean? #start_with?
#
```

`did_you_mean` gem は、エラーメッセージの中に候補となる名前を埋め込んでいる。これは、Google や Git が「実際にアクションをしてから候補を提示する」という方針を採っていて（Google はぞっと洗練されているけど）、この挙動がとても好きだったのでこういう実装になっている。では、Ruby でエラーメッセージに候補を埋め込むにはどうすればよいのか。

## `Exception#to_s` メソッドの上書き

`NoMethodError` は `NameError` を継承しており、さらに `NameError` は、`StandardError`, `Exception` を順に継承している。`Exception` には `#message` と `#to_s` という二つのメソッドが定義されており、どちらでもメッセージを取り出すことができる。また、`#message` は[単に `#to_s` を内部で読んでいるだけ](http://ruby-doc.org/core-2.2.0/Exception.html#method-i-message)なので、`#to_s` を上書きすればよい。

```ruby
class NoMethodError
  def to_s_with_did_you_mean
    msg << original_message
    msg << "\n\n"
    msg << "    Did you mean? ##{suggestions.join(', #')}\n"
  rescue
    original_message
  end

  alias original_message to_s
  alias             to_s to_s_with_did_you_mean
end
```

少し変な実装だが、これはクラスに直接定義されているメソッドを上書きするのに `super` が使えないためである。なので、`alias_method_chain` のようなことを自前でやっている。メッセージに候補を埋め込む過程で `#suggestions` というメソッドを呼んでいるが、当然 `NoMethodError` がこのメソッドを提供しているわけではない。このメソッドも同様に、`NoMethodError` に実装する必要がある。

## `NoMethodError#suggestions` メソッドの実装

先ほどの例で `suggestions` を生成していたコードを、とりあえずそのままコピぺしてみる。

```ruby
class NoMethodError
  THRESHOLD = 2
  
  ...

  def suggestions
    (receiver.methods + receiver.singleton_methods).select do |method_name|
      Levenshtein.distance(method_name, name) < THRESHOLD
    end
  end
end
```

ここでは、`error.name` は `name` へ、`string` というローカル変数は `receiver` という、より抽象化された名前に書き換えてられている。また、特異メソッドが存在する場合も考慮して、`#singleton_methods` からも名前の候補を探すようにしている。ここで、`#name` メソッドは `NameError` クラスによって提供されているものの、`#receiver` メソッドは誰からも提供されていないので、今度はこれを実装しなくてはならない。

## `NoMethodError#receiver` の実装

さて、ここからが問題である。先ほどの例では全ての変数が一つのスコープの中に存在していたので、メソッドが呼ばれていたオブジェクトを容易に呼ぶことができた。しかし、実際の開発現場では `NoMethodError` はどこからともなく発生してくる。エラーメッセージを確認しようとしたスコープから、レシーバとなったオブジェクトにアクセスすることができないという状況は頻繁にある。仮に同じスコープにいたとしても、エラーオブジェクト（この場合は `NoMethodError` のオブジェクト）からの情報だけでどのオブジェクトがレシーバであるかを判別することは難しい。つまり、エラーオブジェクトが生成される過程のどこかで、何がレシーバであったのかをエラーオブジェクトに教えてあげる必要がある。どうやったらそんなことができるのでろうか。

ところで、`NoMethodError` はエラーメッセージの中にレシーバに対して `#inspect` を実行した結果を含んでいる。つまり、C 言語レベルでは `NoMethodError` オブジェクトを生成する過程で、レシーバに対するアクセスがあることが予想される。そのような仮説を立てた上で C で書かれた Ruby のコードを読んでいると、[`make_no_method_exception`](https://github.com/ruby/ruby/blob/d84f9b16/vm_eval.c#L661-L683) という関数で `NoMethodError` が生成されていることが分かった。この関数は、次のようなインタフェースを持っている。

```c
static VALUE
make_no_method_exception(VALUE exc, const char *format, VALUE obj, int argc, const VALUE *argv)
```

ここで `VALUE obj` となっている引数は、まさに求めているレシーバのオブジェクトである。ということは、この関数の中で `obj` を `args` に入れてしまえば、`NoMethodError` はレシーバにアスセスできるようになる。

```c
 static VALUE
 make_no_method_exception(VALUE exc, const char *format, VALUE obj, int argc, const VALUE *argv)
 {
   int n = 0;
   VALUE mesg;
   VALUE args[3];

   if (!format) {
	 format = "undefined method `%s' for %s";
   }
   mesg = rb_const_get(exc, rb_intern("message"));
   if (rb_method_basic_definition_p(CLASS_OF(mesg), '!')) {
     args[n++] = rb_name_err_mesg_new(mesg, rb_str_new2(format), obj, argv[0]);
   }
   else {
     args[n++] = rb_funcall(mesg, '!', 3, rb_str_new2(format), obj, argv[0]);
   }
   args[n++] = argv[0];
   if (exc == rb_eNoMethodError) {
     args[n++] = rb_ary_new4(argc - 1, argv + 1);

     // args[n - 1] = obj
     rb_ary_store(args[n - 1], 0, obj);
   }
   return rb_class_new_instance(n, args, exc);
 }
```

ここで、`rb_ary_store(args[n - 1], 0, obj);` という行は Ruby における

```ruby
args[n - 1] = obj
```

と等価である。この C で書かれたコードを、[rake-compiler](https://github.com/rake-compiler/rake-compiler) でコンパイルすれば Ruby から使えるようになる。`NameError` は [`#args` というメソッドを提供している](http://ruby-doc.org/core-2.2.1/NoMethodError.html#method-i-args)ので、あとは `NoMethodError` に `#args` の最後のオブジェクトを返す `#receiver` メソッドを追加してやればよい。

```ruby
class NoMethodError
  def receiver
    args.last
  end
end
```

> このコードを見て、わざわざ `#args` を使わなくても、`obj` を直接インスタンス変数として渡してしまえばいいんじゃないかと思うかもしれないが、当時は気付かなかった。

実際には、gem が `require` された際に元々実装されている `make_no_method_exception` 関数を置き換えるため、これ以上に複雑なことをやっていた（し、そこにたくさんの時間を費やしてしまった）。しかし、これでようやく名前の候補を探すことができるようになった。ここで、これまでの実装をひとつのスニペットとしてまとめてみよう。

```ruby
require 'did_you_mean/no_method_exception'
require 'did_you_mean/levenshtein'

class NoMethodError
  def to_s_with_did_you_mean
    msg << original_message
    msg << "\n\n"
    msg << "    Did you mean? ##{suggestions.join(', #')}\n"
  rescue
    original_message
  end

  alias original_message to_s
  alias             to_s to_s_with_did_you_mean

  THRESHOLD = 2

  def suggestions
    (receiver.methods + receiver.singleton_methods).select do |method_name|
      DidYouMean::Levenshtein.distance(method_name, name) < THRESHOLD
    end
  end

  def receiver
    args.last
  end
end

"Yuki Nishijima".starts_with?("Yuki)
# => NoMethodError: undefined method `starts_with?' for "Yuki Nishijima":String
#
#    Did you mean? #start_with?
```

## `NameError` にも対応する

名前を間違えた時に発生する例外は `NoMethodError` だけではない。クラス名やモジュール名を間違えれば `NameError: uninitialized constant Foo` となるし、プライベートメソッドやローカル変数の名前を間違えれば `NameError: undefined local variable or method 'foo' for ...` となる。`NoMethodError` と同様に、`NameError` にも名前の候補を埋め込むにはどうしたらよいだろうか。

ローカル変数やメソッドのリストを取ってくることができれば、あとは `NoMethodError` と同様の方法でメッセージに候補を埋め込めそうである。`methods` メソッドでメソッド一覧が取得できることはすでにお話ししたが、同様にローカル変数の一覧も `local_variables` で取得することができる。

```ruby
name = "Yuki NIshijima"
local_variables
# => [:name]
```

そして、`NoMethodError` と同様の問題にぶつかる。`NameError` もどこからともなく発生して、どこか別のスコープで処理されるので、例外が発生したスコープまでさかのぼっていって `methods` と `local_variables` を呼ぶ必要がある。つまり、例外が発生した箇所の `binding` オブジェクトが必要なのである。

### `binding` オブジェクトとは

`binding` オブジェクトとは一体なんなのか。Pat Shaughnessy による `Ruby Under a Microscope` によると、

> A binding is a closure without a function—that is, it’s just the referencing environment. Think of bindings as a pointer to a YARV stack frame.

とある。つまり、`binding` というポインタさえあれば、例外が発生した箇所まで戻ってローカル変数のリストやメソッドを取り出すことができる。では、`binding` を取り出すにはどうしたらよいだろうか。

### `interception` gem

`interception` gem を使うと、例外が発生したときに実行されるコールバック関数を定義することができる。`interception` gem は発生した例外と、例外が発生した箇所の `binding` を渡してくれる。コールバックで渡ってきた `binding` オブジェクトを例外の中に含めてしまえばよさそうだ。`pry-rescue` gem は内部的に `interception` gem を使っているので、`pry-rescue` gem を使ったことがある人は何がやりたいのかイメージが湧きやすいかもしれない。

```ruby
require 'interception'

Interception.listen(->(exception, binding) {
  exception.instance_variable_set(:@frame_binding)
})

def raise_name_error
  full_name = "Yuki Nishijima"
  ful_name
end

error = raise_name_error rescue $!
error.instance_variable_get(:@frame_binding).eval("local_variables")
# => [:full_name]
```

これで、ローカル変数のリストも、メソッドのリストも取得することができた。

蛇足だが、`interception` gem は MRI 2.0 以上では Tracepoint API を使っている。Tracepoint API は Ruby 2.0 以降で有効なので、`interception` gem を使うことなく実装することも可能だ。しかし、Ruby 1.9.3 や JRuby, Rubinius のサポートのことも考えると、これら全てをサポートしている `interception` gem を使う方が楽だと言える。

### クラス名とモジュール名の補足


### リファクタリング


# 実際に使ってみる

とりあえず動くものができたので、手元にある Rails アプリで使ってみることにした。Gemfile に `gem "did_you_mean", path: "../did_you_mean"` を追加して `bundle` を実行、テストの一部に意図的にスペスミスを加えて `rake spec` を実行する。これで、エラー結果に "Did you mean?" が表示されるはずだ。

...**遅い。**

嬉しいことに "Did you mean?" は表示された。しかし、3分あれば終わるはずの `rake spec` が13分以上かかってしまった。これではとてもじゃないが使い物にならない。一体なぜこんなに遅くなってしまったのだろうか。

`did_you_mean` に遅くなる原因があるとすれば、Levenshtein アルゴリズムだ。存在するメソッド全てと入力されたメソッド名の距離をそれぞれ計算するのだから、ある程度時間がかかるのは分かる。しかし、それをたった1回実行しただけでこんなに実行時間が長くなるのはおかしい。それに、irb 上で適当にメソッドを実行して `NoMethodError` を発生させても、結果はすぐに返ってくる。

原因が Levenshtein アルゴリズムにあることを確かめるため、距離を計算するメソッドを常に 100 を返すように変更した。すると、実行時間は元に戻った。つまり、Levenshtein アルゴリズム以外の `did_you_mean` の実装に問題はなく、やはり Levenshtein が根本的な原因であると考えられる。

他に考えられる可能性として、Levenshtein アルゴリズムが大量に呼ばれているのではないかと考えた。`did_you_mean` の実装に問題はなく、1度の実行ならすぐに終わるが、複数回呼ばれていれば遅くなる可能性は十分に考えられる。では、どうやってそれを確かめたらよいか。そこで、`Exception#to_s` に簡単なモンキーパッチを当てて再度テストを走らせてみた。

```diff
def to_s
　 puts "I'm getting called too many times!"
end
```

すると、大量の `I'm getting called too many times!` が表示された。やはり、誰かが大量に `#to_s` を呼んでいるようだ。

## 誰が `Exception#to_s` を呼んでいるのか

一体誰が `Exception#to_s` を大量に呼んでいるを知るために、[`#caller`](http://ruby-doc.org/core-2.2.1/Kernel.html#method-i-caller) を `#to_s` の中で呼び、その結果を表示してみた。`#caller` は、呼ばれた時点でのバックトレースを返すメソッドなので、これを見れば誰に呼ばれたのかを特定することができる。

```ruby
def to_s
  puts caller
end
```

この結果を一部を抜粋すると、次のようになる。

```
active_support/core_ext/name_error.rb:5:in `message'
active_support/core_ext/name_error.rb:5:in `missing_name'
active_support/core_ext/name_error.rb:15:in `missing_name?'
active_support/dependencies.rb:516:in `rescue in load_missing_constant'
active_support/dependencies.rb:513:in `load_missing_constant'
active_support/dependencies.rb:192:in `block in const_missing'
active_support/dependencies.rb:190:in `each'
active_support/dependencies.rb:190:in `const_missing'
...
```

どうやら、ActiveSupport がクラスをロードする過程で、クラス名をエラーメッセージから取り出しているようである。Rails 上では、`app/` 以下の定義されているクラスとモジュールのロードが `ActiveSupport::Dependencies` を介して行われるので、コンスタントの数だけ `#to_s` が呼ばれていることになる。そして、`did_you_mean` gem は必要もないのに候補を探そうとしてしまう。ここでは、人間が何かを入力しているわけではないので、`ActiveSupport::Dependencies` がメッセージを呼ぼうとした場合は通常のメッセージをそのまま返すようにすればよい。

```ruby
def to_s_with_did_you_mean
  msg << original_message
  if caller.first(8).grep(/( |`)missing_name'/).empty?
    msg << "\n\n"
    msg << "    Did you mean? #{suggestions.join(', ')}\n"
  end
  msg
rescue
  original_message
end

alias original_message to_s
alias             to_s to_s_with_did_you_mean
```

この実装を行った上で再度 `rake spec` を走らせると、見事パフォーマンスの劣化なく、かつエラーメッセージに名前の候補を表示することに成功した。

> 最近になって `#safe_constantize` もパフォーマンスを劣化させる原因になることが判明したため、現在は[無視する呼び出し元を簡単に追加できるような設計](https://github.com/yuki24/did_you_mean/blob/c07ed604/lib/did_you_mean/core_ext/name_error.rb#L4-L16)になっている。報告をして頂いた [@tleish](https://github.com/tleish) 氏に感謝の意を表する。

## バグとの戦い

これで `did_you_mean` はいい感じになったと思われたが、これだけでは終わらなかった。`NoMethodError#receiver` を実装するために必要となった C 拡張のコードが、Ruby 自体の挙動を破壊していた。[GitHub 上の issues に報告](https://github.com/yuki24/did_you_mean/issues/14)があり、探してみると [letter_opener](https://github.com/ryanb/letter_opener/issues/97) や [arel](https://github.com/rails/arel/pull/336) にまで影響を与えていた。大問題である。そもそもこの C 拡張コードには、一部の Mac OS X 上でコンパイルできないという問題もあり、これではまずいということはずっと前から認識していたことだが、まさか本当にこんな問題になってしまうとは。

ちょうどその問題で頭を抱えていた2週間後には [RubyConf 2014](http://rubyconf.org/) を控えており、そこには何人か Ruby commiters がやって来るかもしれないと睨んでいた。実際に San Diego まで行ってみると、ささださんやなかださんが来ていることが分かったので、早速初日の夜に相談してみることにした。

...**なかださんが速攻で直してくれた。**

自分が何時間もかけて悩み、大量のコードを書き、重大なバグを生んでしまったのに対して、なかださんは何のバグを生み出すこともなく、たった数十行のコードをものの 20 分程度で実装してしまった。何倍の生産性というのは、こういうことをいうのだろう。自分の実装は、非常に低層にある関数を置き換えるために、書き換える必要のない関数やヘッダファイルを Ruby のソースコードから文字通りコピーしていた。その行数は実に28,000行以上。とても良いとはいえない、というか、最悪である。

こうして[なかださんの実装が取り込まれ](https://github.com/yuki24/did_you_mean/commit/972c16716266de105e94a46609b8538b591bd40c)、`did_you_mean` gem はようやく普通に使えるものになったのである。

> 余談だが、リモートワークの環境が発達した現在でも、時差のある地域とは情報交換をしずらいし、コードがなければ説明の難しい状況下では in-person でのペアプロに勝るものはない。カンファレンスの真価は、世界中に分散した開発者が一同に会することで、リモートでは難しい議論やハックができるところにあると思う。逆に言えば、リモートでも済むようなこと（たとえば、単に発表を聞いて帰る）をするだけでは、お金を払ってくる価値はないだろう。

## Wrapping up


# 最近の新機能

  * JRuby, Rubinius の対応
  * より有用な名前の候補の推薦
  * 他の gem との連携強化

## JRuby, Rubinius の対応

### JRuby 1.7.19 に対応した

今すぐ試せるよ！

### JRuby 9000 にも対応するよ

今はまだ動かないけど、対応する予定だよ。

### Rubinius 2.4.1, 2.5.2 に対応した

動かない機能もあるよ。

## 名前推薦の改善、より有用な候補探索

### 表示結果が上から似ている順にソートされるようにした

### クラス変数を名前の候補として提示するようにした

### インスタンス変数をスペルミスして `nil` に対する `NoMethodError` が発生したら、正しい変数名を探すようにした

## 他の gem との連携強化

### `pry` 上で色付けをするようにした

### `better_errors` 上で専用のセクションを設けるようにした

## アイデアがあったら教えてね！

# Special Thanks
