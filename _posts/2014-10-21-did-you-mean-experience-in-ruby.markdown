---
layout: post
title:  '"Did you mean?" Experience in Ruby'
date:   2014-10-21 23:39:54
categories: engineering
location: New York, United States
tags: ruby rails
---

Everytime I misspelled a method name or a class name and got an error but didn't realize the typo, I kept saying,

> _"Weird, nothing looks weird..."_

Sometimes I wasted hours and hours just because there is one character difference. I hate it.

This is why I created [`did_you_mean`](https://github.com/yuki24/did_you_mean) gem. With it, whenever you get `NoMethodError` or `NameError`, it'll automatically look for what you really wanted to call and tell it to you.

```ruby
gem 'did_you_mean', group: [:development, :test]
```

So what will happen when you misspell ActiveSupport's `Hash#with_indifferent_access`? Here is what it looks like:

```ruby
hash.with_inddiferent_access
# => NoMethodError: undefined method `with_inddiferent_access' for {}:Hash
#
#     Did you mean? #with_indifferent_access
#
```

Look! Now you can just copy and paste what was suggested and it'll just work.

`did_you_mean` gem automagically puts method suggestions into the error message. This means you'll have the _"Did you mean?"_ experience almost everywhere. Here is a good example of a suggestion from my real development:

<img
  src="/img/2014-10-21-did-you-mean-experience-in-ruby/screenshot.png"
  alt="Example of a method suggestion in real development"
  width="100%" />

You can find more examples on the project page on GitHub: [yuki24/did\_you\_mean](https://github.com/yuki24/did_you_mean)

Start using [`did_you_mean`](https://github.com/yuki24/did_you_mean) gem and stop worrying about misspelling. Ruby will just read your mind.
