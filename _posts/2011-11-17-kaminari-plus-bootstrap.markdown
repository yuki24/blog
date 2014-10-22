---
layout: post
title:  "Kaminari + Bootstrap = <3"
date:   2012-11-17 21:09:06
categories: engineering
location: Tokyo, Japan
tags: ruby rails kaminari bootstrap
---

As you can notice on an everyday basis, twitter bootstrap is being used in many services today. If you've developed a web application with Ruby on Rails and needed to implement pagination, you've probably used [kaminari](https://github.com/amatsuda/kaminari) or [will_paginate](https://github.com/mislav/will_paginate) as well.

Even so, applying twitter bootstrap to kaminari's default template, while not technically difficult, requires several tedious operations. There are also lots of blog posts explaining different methods and gems that make the process easier. However, the problem is that bootstrap development moves at a bleeding-edge pace, so those posts quickly become obsolete. These changes also create a steep hurdle for beginners.

In order to eliminate these complexities, kaminari started supporting twitter bootstrap several weeks ago. This integration will make the process much easier. All that's required is just issuing a one-line command. No need to use other gems.

# Background

About a month ago at the [Asakusa.rb](http://qwik.jp/asakusarb/) meetup, the kaminari author, [Matsuda-san](https://twitter.com/a_matsuda), told me that there had been as many as eight pull requests for support for twitter bootstrap on kaminari themes' Github Issues. a few weeks later, [Hibariya-san](https://twitter.com/hibariya) and I tested all of the requests and merged @jweslley's pull reuqest.

# Installation

When using twitter bootstrap with Ruby on Rails, installing via gem is the standard approach. The obvious choices are [twitter-bootstrap-rails](https://github.com/seyhunak/twitter-bootstrap-rails) and [bootstrap-sass](https://github.com/thomas-mcdonald/bootstrap-sass) -- both will immediately adapt to changes to bootstrap proper, so there should be no issue with choosing one over the other. For the purposes of this tutorial, I'll use `twitter-bootstrap-rails` because it offers some convenient commands that let you easily change existing templates to the bootstrap format.

First, make sure your Gemfile contains the following lines.

```ruby
gem 'kaminari'
gem 'twitter-bootstrap-rails', :group => :assets 
```

If bootstrap is not installed, use the following command to install it.

```
bundle install
rails g bootstrap:install
rails g bootstrap:layout application fluid
```

Once installed, you can issue the following command to generate a bootstrap-compatible template.

```
rails g kaminari:views bootstrap
```

That's it! You should reboot rails server and make sure everything is working as expected.

# Demo

I build a simple demo application running on heroku: [https://kaminari-bootstrap-demo.herokuapp.com/](https://kaminari-bootstrap-demo.herokuapp.com/)

[The source code is on GitHub.](https://github.com/yuki24/kaminari-bootstrap-demo).

We were able to merge @jweslley's request without any changes to his code, letting us create clean layouts with this update. Even so, bootstrap is updated on an almost daily basis, so this template will probably be deprecated before long. If your layout breaks or you notice your templates need updating, please send those changes on [kaminari_themes on github](https://github.com/amatsuda/kaminari_themes). If you run into other non-layout issues, try posting a question on stackoverflow -- you'll probably be able to get a response right away, so it's worth trying as a method of first resort.
